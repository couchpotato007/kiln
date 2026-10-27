package subset_font

// Writes a TrueType font that keeps only the glyphs of the given codepoints, for embedding into
// kiln apps (the full Iosevka files are ~11.5 MB each, the subsets ~100 KB):
//
//   odin run tools/subset_font -- resources/Iosevka-Regular.ttf resources/kiln-regular.ttf
//   odin run tools/subset_font -- in.ttf out.ttf U+20-7E,U+A0-17F
//
// Without a range list it keeps Latin, punctuation, arrows, geometric shapes and a few symbols.
// Characters a subset lacks can come from `font_fallbacks` in the theme. Same idea as
// `pyftsubset in.ttf --unicodes=... --output-file=out.ttf`, without needing Python.
//
// Kept tables: head, hhea, maxp, OS/2, hmtx, name, a new cmap (format 4), a version 3 post and
// glyf / loca / hmtx with only the kept glyphs (renumbered densely).
// Layout and hinting tables (GSUB, GPOS, GDEF, fpgm, prep, cvt) are dropped; kiln's renderers
// use neither.

import "core:encoding/endian"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"

KILN_RANGES :: "U+20-7E,U+A0-17F,U+2010-205E,U+20AC,U+2190-21FF,U+2212,U+22EF,U+2302,U+25A0-25FF,U+2600-2609,U+2630,U+2699,U+2713-2718"

Table :: struct {
	tag:  string,
	data: []u8,
}

main :: proc() {
	if len(os.args) < 3 {
		fmt.eprintln("usage: subset_font <in.ttf> <out.ttf> [U+20-7E,U+A0-17F,...]")
		os.exit(2)
	}
	ranges := len(os.args) > 3 ? os.args[3] : KILN_RANGES
	src, err := os.read_entire_file(os.args[1], context.allocator)
	if err != nil {
		fmt.eprintln("cannot read", os.args[1])
		os.exit(1)
	}
	out, ok := subset(src, parse_ranges(ranges))
	if !ok {
		fmt.eprintln("not a TrueType font with glyf outlines:", os.args[1])
		os.exit(1)
	}
	if os.write_entire_file(os.args[2], out) != nil {
		fmt.eprintln("cannot write", os.args[2])
		os.exit(1)
	}
	fmt.printf("%s: %d -> %d bytes\n", os.args[2], len(src), len(out))
}

parse_ranges :: proc(s: string) -> []rune {
	cps: [dynamic]rune
	for part in strings.split(s, ",") {
		p := strings.trim_prefix(strings.to_upper(strings.trim_space(part)), "U+")
		lo_s, _, hi_s := strings.partition(p, "-")
		lo, _ := strconv.parse_int(lo_s, 16)
		hi := lo
		if len(hi_s) > 0 {hi, _ = strconv.parse_int(hi_s, 16)}
		for r in lo ..= hi {append(&cps, rune(r))}
	}
	return cps[:]
}

u16be :: proc(b: []u8, off: int) -> int {return int(endian.unchecked_get_u16be(b[off:]))}
u32be :: proc(b: []u8, off: int) -> int {return int(endian.unchecked_get_u32be(b[off:]))}
i16be :: proc(b: []u8, off: int) -> int {return int(i16(endian.unchecked_get_u16be(b[off:])))}

put16 :: proc(b: ^[dynamic]u8, v: int) {append(b, u8(v >> 8), u8(v))}
put32 :: proc(b: ^[dynamic]u8, v: int) {append(b, u8(v >> 24), u8(v >> 16), u8(v >> 8), u8(v))}

subset :: proc(src: []u8, cps: []rune) -> ([]u8, bool) {
	if len(src) < 12 || u32be(src, 0) != 0x00010000 {return nil, false}
	tables := make(map[string][]u8)
	for i in 0 ..< u16be(src, 4) {
		rec := 12 + 16 * i
		off, length := u32be(src, rec + 8), u32be(src, rec + 12)
		tables[string(src[rec:rec + 4])] = src[off:off + length]
	}
	for t in ([]string{"head", "hhea", "maxp", "hmtx", "cmap", "loca", "glyf"}) {
		if t not_in tables {return nil, false}
	}
	head, glyf, loca := tables["head"], tables["glyf"], tables["loca"]
	num_glyphs := u16be(tables["maxp"], 4)
	long_loca := i16be(head, 50) == 1
	glyph_range :: proc(loca: []u8, long: bool, g: int) -> (int, int) {
		if long {return u32be(loca, 4 * g), u32be(loca, 4 * g + 4)}
		return 2 * u16be(loca, 2 * g), 2 * u16be(loca, 2 * g + 2)
	}

	// Glyphs to keep: .notdef, the mapped ones and the components of composite glyphs.
	mapping := make([dynamic][2]int) // codepoint, glyph
	keep := make([]bool, num_glyphs)
	keep[0] = true
	for r in cps {
		if g := cmap_lookup(tables["cmap"], int(r)); g > 0 && g < num_glyphs {
			append(&mapping, [2]int{int(r), g})
			keep[g] = true
		}
	}
	stack := make([dynamic]int)
	for k, g in keep {if k {append(&stack, g)}}
	for len(stack) > 0 {
		g := pop(&stack)
		a, b := glyph_range(loca, long_loca, g)
		if b - a < 10 || i16be(glyf, a) >= 0 {continue}
		p := a + 10
		for {
			flags, comp := u16be(glyf, p), u16be(glyf, p + 2)
			if comp < num_glyphs && !keep[comp] {
				keep[comp] = true
				append(&stack, comp)
			}
			p += 4 + ((flags & 0x0001) != 0 ? 4 : 2)
			switch {
			case flags & 0x0008 != 0:
				p += 2
			case flags & 0x0040 != 0:
				p += 4
			case flags & 0x0080 != 0:
				p += 8
			}
			if flags & 0x0020 == 0 {break}
		}
	}

	// The kept glyphs get new, dense ids (in their old order, so .notdef stays 0).
	new_id := make([]int, num_glyphs)
	kept := make([dynamic]int)
	for k, g in keep {
		if !k {continue}
		new_id[g] = len(kept)
		append(&kept, g)
	}
	for &m in mapping {m[1] = new_id[m[1]]}

	// glyf with the component ids of composite glyphs renumbered, and a long loca for it.
	new_glyf := make([dynamic]u8)
	new_loca := make([dynamic]u8)
	for g in kept {
		put32(&new_loca, len(new_glyf))
		a, b := glyph_range(loca, long_loca, g)
		start := len(new_glyf)
		append(&new_glyf, ..glyf[a:b])
		if b - a >= 10 && i16be(glyf, a) < 0 {
			p := start + 10
			for {
				flags := u16be(new_glyf[:], p)
				endian.unchecked_put_u16be(new_glyf[p + 2:], u16(new_id[u16be(new_glyf[:], p + 2)]))
				p += 4 + ((flags & 0x0001) != 0 ? 4 : 2)
				switch {
				case flags & 0x0008 != 0:
					p += 2
				case flags & 0x0040 != 0:
					p += 4
				case flags & 0x0080 != 0:
					p += 8
				}
				if flags & 0x0020 == 0 {break}
			}
		}
		for len(new_glyf) % 4 != 0 {append(&new_glyf, 0)}
	}
	put32(&new_loca, len(new_glyf))

	// hmtx with a full metric per kept glyph.
	hmtx := tables["hmtx"]
	long_metrics := u16be(tables["hhea"], 34)
	new_hmtx := make([dynamic]u8)
	for g in kept {
		if g < long_metrics {
			append(&new_hmtx, ..hmtx[4 * g:4 * g + 4])
		} else {
			append(&new_hmtx, ..hmtx[4 * (long_metrics - 1):4 * (long_metrics - 1) + 2])
			lsb := 4 * long_metrics + 2 * (g - long_metrics)
			append(&new_hmtx, ..hmtx[lsb:lsb + 2])
		}
	}
	new_hhea := slice.clone(tables["hhea"])
	endian.unchecked_put_u16be(new_hhea[34:], u16(len(kept)))
	new_maxp := slice.clone(tables["maxp"])
	endian.unchecked_put_u16be(new_maxp[4:], u16(len(kept)))

	new_head := slice.clone(head)
	new_head[50], new_head[51] = 0, 1 // indexToLocFormat: long
	for i in 8 ..< 12 {new_head[i] = 0} // checkSumAdjustment, set below

	// post version 3: no glyph names.
	new_post := make([dynamic]u8)
	if post, has := tables["post"]; has && len(post) >= 32 {
		append(&new_post, ..post[:32])
		new_post[0], new_post[1], new_post[2], new_post[3] = 0, 3, 0, 0
	}

	out_tables := make([dynamic]Table)
	append(&out_tables, Table{"cmap", build_cmap(mapping[:])})
	append(&out_tables, Table{"glyf", new_glyf[:]})
	append(&out_tables, Table{"head", new_head})
	append(&out_tables, Table{"hhea", new_hhea})
	append(&out_tables, Table{"hmtx", new_hmtx[:]})
	append(&out_tables, Table{"loca", new_loca[:]})
	append(&out_tables, Table{"maxp", new_maxp})
	if name, has := tables["name"]; has {append(&out_tables, Table{"name", name})}
	if os2, has := tables["OS/2"]; has {append(&out_tables, Table{"OS/2", os2})}
	if len(new_post) > 0 {append(&out_tables, Table{"post", new_post[:]})}
	slice.sort_by(out_tables[:], proc(a, b: Table) -> bool {return a.tag < b.tag})
	return write_font(out_tables[:]), true
}

// The glyph of a codepoint from a Windows Unicode subtable (format 4 or 12), 0 if none.
cmap_lookup :: proc(cmap: []u8, cp: int) -> int {
	for i in 0 ..< u16be(cmap, 2) {
		rec := 4 + 8 * i
		platform, encoding := u16be(cmap, rec), u16be(cmap, rec + 2)
		if !(platform == 3 && (encoding == 1 || encoding == 10)) && platform != 0 {continue}
		sub := u32be(cmap, rec + 4)
		switch u16be(cmap, sub) {
		case 12:
			for gi in 0 ..< u32be(cmap, sub + 12) {
				g := sub + 16 + 12 * gi
				start, end := u32be(cmap, g), u32be(cmap, g + 4)
				if cp >= start && cp <= end {return u32be(cmap, g + 8) + cp - start}
			}
		case 4:
			segs := u16be(cmap, sub + 6) / 2
			ends := sub + 14
			starts := ends + 2 * segs + 2
			deltas := starts + 2 * segs
			offsets := deltas + 2 * segs
			for s in 0 ..< segs {
				if cp > u16be(cmap, ends + 2 * s) {continue}
				start := u16be(cmap, starts + 2 * s)
				if cp < start {break}
				ro := u16be(cmap, offsets + 2 * s)
				if ro == 0 {return (cp + i16be(cmap, deltas + 2 * s)) & 0xFFFF}
				g := u16be(cmap, offsets + 2 * s + ro + 2 * (cp - start))
				return g == 0 ? 0 : (g + i16be(cmap, deltas + 2 * s)) & 0xFFFF
			}
		}
	}
	return 0
}

// A cmap with one format 4 subtable (Windows, Unicode BMP), one segment per run of codepoints
// whose glyph ids increase with them.
build_cmap :: proc(mapping: [][2]int) -> []u8 {
	Seg :: struct {
		start, end, delta: int,
	}
	segs := make([dynamic]Seg)
	for m in mapping {
		cp, g := m[0], m[1]
		if cp > 0xFFFE {continue}
		if n := len(segs); n > 0 && segs[n - 1].end == cp - 1 && segs[n - 1].delta == g - cp {
			segs[n - 1].end = cp
		} else {
			append(&segs, Seg{cp, cp, g - cp})
		}
	}
	append(&segs, Seg{0xFFFF, 0xFFFF, 1})

	n := len(segs)
	entry_selector := 0
	for (1 << uint(entry_selector + 1)) <= n {entry_selector += 1}
	search_range := 2 * (1 << uint(entry_selector))

	sub := make([dynamic]u8)
	put16(&sub, 4)
	put16(&sub, 16 + 8 * n) // length
	put16(&sub, 0) // language
	put16(&sub, 2 * n)
	put16(&sub, search_range)
	put16(&sub, entry_selector)
	put16(&sub, 2 * n - search_range)
	for s in segs {put16(&sub, s.end)}
	put16(&sub, 0) // reserved
	for s in segs {put16(&sub, s.start)}
	for s in segs {put16(&sub, s.delta & 0xFFFF)}
	for _ in segs {put16(&sub, 0)} // idRangeOffset

	b := make([dynamic]u8)
	put16(&b, 0) // version
	put16(&b, 1) // one subtable
	put16(&b, 3) // Windows
	put16(&b, 1) // Unicode BMP
	put32(&b, 12)
	append(&b, ..sub[:])
	return b[:]
}

checksum :: proc(data: []u8) -> u32 {
	sum: u32 = 0
	for i := 0; i < len(data); i += 4 {
		w: u32 = 0
		for j in 0 ..< 4 {
			w <<= 8
			if i + j < len(data) {w |= u32(data[i + j])}
		}
		sum += w
	}
	return sum
}

write_font :: proc(tables: []Table) -> []u8 {
	n := len(tables)
	entry_selector := 0
	for (1 << uint(entry_selector + 1)) <= n {entry_selector += 1}
	search_range := 16 * (1 << uint(entry_selector))

	out := make([dynamic]u8)
	put32(&out, 0x00010000)
	put16(&out, n)
	put16(&out, search_range)
	put16(&out, entry_selector)
	put16(&out, 16 * n - search_range)

	offset := 12 + 16 * n
	head_at := -1
	for t in tables {
		append(&out, ..transmute([]u8)t.tag)
		put32(&out, int(checksum(t.data)))
		put32(&out, offset)
		put32(&out, len(t.data))
		if t.tag == "head" {head_at = offset}
		offset += (len(t.data) + 3) &~ 3
	}
	for t in tables {
		append(&out, ..t.data)
		for len(out) % 4 != 0 {append(&out, 0)}
	}
	if head_at >= 0 {
		adj := 0xB1B0AFBA - checksum(out[:])
		endian.unchecked_put_u32be(out[head_at + 8:], adj)
	}
	return out[:]
}
