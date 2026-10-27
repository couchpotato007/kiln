package docgen

// Turns the `.odin-doc` file of kiln into Markdown pages for the Astro site in docs/, one page
// per topic with the signature, a table of the arguments (type and default) and the doc comment
// of every exported entity:
//
//   odin doc kiln -collection:lib=. -doc-format -out:docs/kiln.odin-doc
//   odin run tools/docgen -- docs/kiln.odin-doc docs/src/content/docs/api
//
// (`pnpm api` in docs/ runs both.) The pages are generated, do not edit them by hand. Which file
// lands on which page is decided by PAGES below; files that are not listed go to "Other".
//
// The .odin-doc file knows the entities, their doc comments and where they are declared, but its
// types are resolved: aliases like `Color` turn into `[4]f32` and `lo, hi: T` into `$T`. So
// signatures and field types are taken from the source text at the recorded position, and the
// resolved types only fill in what the source leaves out (`key := ""` is a string).

import doc "core:odin/doc-format"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

Page :: struct {
	slug:        string,
	title:       string,
	description: string,
	files:       []string,
}

PAGES := []Page {
	{"app", "App", "Running an app, the message loop, tasks, timers, input and the clipboard.", {"app.odin", "task.odin", "backend_raylib.odin", "backend_snapshot.odin"}},
	{"layout", "Layout", "Containers: column, row, card, grid, adaptive, flow, field, actions, scroll, ...", {"layout.odin"}},
	{"controls", "Controls", "Buttons, checkboxes, toggles, radios, sliders and text fields.", {"controls.odin", "text_field.odin"}},
	{"choices", "Choices", "Tabs, segmented controls, navigation and selects.", {"choice.odin"}},
	{"display", "Display", "Text, badges, avatars, progress, stats, callouts, chips and empty states.", {"display.odin", "extras.odin"}},
	{"charts", "Charts", "Bar charts, timelines, legends and swatches.", {"chart.odin"}},
	{"data", "Tables and trees", "Sortable tables and trees.", {"table.odin", "tree.odin"}},
	{"dates", "Dates", "The Date type, date math, date fields and the calendar.", {"date.odin"}},
	{"overlays", "Overlays", "Dialogs, drawers, toasts, menus, context menus and tooltips.", {"dialog.odin", "menu.odin"}},
	{"icons", "Icons", "Icons from SVG, images and font glyphs.", {"icon.odin", "svg.odin"}},
	{"theme", "Theme and units", "Colors, metrics, Catppuccin, fonts and turning theme steps into pixels.", {"theme.odin", "catppuccin.odin", "fonts.odin", "units.odin"}},
	{"state", "State and ids", "Ids, scopes, item queries, widget state, animation, dialogs by name and timers.", {"state.odin"}},
	{"paint", "Painting", "Lines, circles and images drawn into an element, for custom widgets.", {"paint.odin"}},
}

OTHER :: Page{"other", "Other", "Everything that did not fit anywhere else.", nil}

Item :: struct {
	name:   string,
	entity: ^doc.Entity,
	file:   string,
}

// One parameter or result as written in the source. `lo, hi: T` gives two with the same type.
Param :: struct {
	name, type, default: string,
}

Signature :: struct {
	text:    string, // `proc(...) -> ...` with the whitespace collapsed
	params:  []Param,
	results: []Param,
	groups:  []string, // the parameters as written, `lo, hi: T` in one piece
}

h: ^doc.Header
base: ^doc.Header_Base
files: []doc.File
entities: []doc.Entity
types: []doc.Type
pkg_name: string
anchor_of: map[string]string // entity name -> "page/#anchor", for links
sources: map[doc.File_Index]string

main :: proc() {
	if len(os.args) < 3 {
		fmt.eprintln("usage: docgen <kiln.odin-doc> <out dir>")
		os.exit(2)
	}
	data, err := os.read_entire_file(os.args[1], context.allocator)
	if err != nil {
		fmt.eprintln("cannot read", os.args[1])
		os.exit(1)
	}
	rerr: doc.Reader_Error
	h, rerr = doc.read_from_bytes(data)
	if rerr != .None {
		fmt.eprintln("not a .odin-doc file of this Odin version:", rerr)
		os.exit(1)
	}
	base = &h.base
	files = doc.from_array(base, h.files)
	entities = doc.from_array(base, h.entities)
	types = doc.from_array(base, h.types)

	// The package that was documented is the one with the Init flag.
	pkg: ^doc.Pkg
	for &p in doc.from_array(base, h.pkgs) {
		if .Init in p.flags {pkg = &p}
	}
	if pkg == nil {
		fmt.eprintln("no package in", os.args[1])
		os.exit(1)
	}
	pkg_name = str(pkg.name)

	// Sort the exported entities onto their pages.
	by_page := make(map[string][dynamic]Item)
	for entry in doc.from_array(base, pkg.entries) {
		e := &entities[entry.entity]
		name := str(entry.name)
		file := file_name(e.pos.file)
		if .Private in e.flags || strings.has_suffix(file, "_test.odin") {continue}
		if e.kind == .Import_Name || e.kind == .Library_Name {continue}
		slug := page_for(file).slug
		items := by_page[slug]
		append(&items, Item{name, e, file})
		by_page[slug] = items
	}

	out_dir := os.args[2]
	if os.make_directory_all(out_dir) != nil && !os.is_dir(out_dir) {
		fmt.eprintln("cannot create", out_dir)
		os.exit(1)
	}

	all_pages := make([dynamic]Page)
	append(&all_pages, ..PAGES)
	append(&all_pages, OTHER)
	// Anchors the way Starlight makes them: lowercase, and `-1` for the second heading with the
	// same text on a page (`Space` the type and `space` the proc).
	for page in all_pages {
		items, ok := by_page[page.slug]
		if !ok {continue}
		slice.sort_by(items[:], proc(a, b: Item) -> bool {return a.name < b.name})
		seen := make(map[string]int, context.temp_allocator)
		seen["at-a-glance"] = 1
		for k in SECTIONS {
			for it in items {
				if it.entity.kind != k.kind {continue}
				a := strings.to_lower(it.name)
				n := seen[a]
				seen[a] = n + 1
				anchor_of[it.name] = n == 0 ? fmt.aprintf("%s/#%s", page.slug, a) : fmt.aprintf("%s/#%s-%d", page.slug, a, n)
			}
		}
	}

	order := 2 // 1 is the hand-written overview
	for page in all_pages {
		items, ok := by_page[page.slug]
		if !ok {continue}
		path := fmt.tprintf("%s/%s.md", out_dir, page.slug)
		if os.write_entire_file(path, write_page(page, items[:], order)) != nil {
			fmt.eprintln("cannot write", path)
			os.exit(1)
		}
		fmt.printf("%s: %d entries\n", path, len(items))
		order += 1
	}
}

page_for :: proc(file: string) -> Page {
	for p in PAGES {
		if slice.contains(p.files, file) {return p}
	}
	return OTHER
}

str :: proc(s: doc.String) -> string {return doc.from_string(base, s)}

file_name :: proc(f: doc.File_Index) -> string {
	if f == 0 {return ""}
	full := str(files[f].name)
	i := strings.last_index_any(full, "/\\")
	return full[i + 1:]
}

// The source file an entity is declared in and its offset there ("" if unknown).
source_of :: proc(e: ^doc.Entity) -> (src: string, offset: int) {
	if e.pos.file == 0 {return}
	ok: bool
	src, ok = sources[e.pos.file]
	if !ok {
		data, err := os.read_entire_file(str(files[e.pos.file].name), context.allocator)
		if err == nil {src = string(data)}
		sources[e.pos.file] = src
	}
	if int(e.pos.offset) >= len(src) {return "", 0}
	return src, int(e.pos.offset)
}

// The source text from the entity's position to the end of the file.
source_at :: proc(e: ^doc.Entity) -> string {
	src, offset := source_of(e)
	return src[offset:]
}

// The comment lines right above a struct field and the comment at the end of its line.
// (The .odin-doc file has them too, but in groups like `a, b: T // ...` they end up on the
// wrong field.)
field_notes :: proc(e: ^doc.Entity) -> string {
	src, offset := source_of(e)
	if src == "" {return ""}
	line_start := strings.last_index_byte(src[:offset], '\n') + 1
	line_end := strings.index_byte(src[offset:], '\n')
	line_end = line_end < 0 ? len(src) : offset + line_end

	parts := make([dynamic]string, context.temp_allocator)
	above := make([dynamic]string, context.temp_allocator)
	for end := line_start - 1; end > 0; {
		start := strings.last_index_byte(src[:end], '\n') + 1
		l := strings.trim_space(src[start:end])
		if !strings.has_prefix(l, "//") {break}
		inject_at(&above, 0, strings.trim_space(l[2:]))
		end = start - 1
	}
	append(&parts, ..above[:])
	line := src[line_start:line_end]
	if i := find_top(line, "/"); i >= 0 && i + 1 < len(line) && line[i + 1] == '/' {
		append(&parts, strings.trim_space(line[i + 2:]))
	}
	return strings.join(parts[:], " ", context.temp_allocator)
}

// Page

Kind_Section :: struct {
	kind:  doc.Entity_Kind,
	title: string,
}

SECTIONS :: [?]Kind_Section{{.Type_Name, "Types"}, {.Proc_Group, "Procedure groups"}, {.Procedure, "Procedures"}, {.Constant, "Constants"}, {.Variable, "Variables"}}

write_page :: proc(page: Page, items: []Item, order: int) -> string {
	b := strings.builder_make()
	fmt.sbprintf(&b, "---\ntitle: %q\ndescription: %q\nsidebar:\n  order: %d\n---\n\n", page.title, page.description, order)
	fmt.sbprint(&b, ":::note\nThis page is generated from the doc comments in `kiln/` by `tools/docgen`. Fix the comment, not the page.\n:::\n\n")

	// Every declaration in one block, to look up arguments without scrolling.
	fmt.sbprint(&b, "## At a glance\n\n```odin\n")
	for k in SECTIONS {
		for it in items {
			if it.entity.kind == k.kind {fmt.sbprintln(&b, short_decl(it))}
		}
	}
	fmt.sbprint(&b, "```\n\n")

	for k in SECTIONS {
		n := 0
		for it in items {if it.entity.kind == k.kind {n += 1}}
		if n == 0 {continue}
		fmt.sbprintf(&b, "## %s\n\n", k.title)
		for it in items {
			if it.entity.kind == k.kind {write_item(&b, it)}
		}
	}
	return strings.to_string(b)
}

// One line per entity for the overview.
short_decl :: proc(it: Item) -> string {
	e := it.entity
	#partial switch e.kind {
	case .Procedure:
		return fmt.tprintf("%s :: %s", it.name, signature(e).text)
	case .Proc_Group:
		return fmt.tprintf("%s :: proc{{%s}}", it.name, strings.join(group_names(e), ", ", context.temp_allocator))
	case .Type_Name:
		decl := type_source(e)
		if i := strings.index_byte(decl, '{'); i >= 0 {return fmt.tprintf("%s {{...}}", collapse(decl[:i]))}
		return collapse(decl)
	case .Constant:
		return fmt.tprintf("%s :: %s", it.name, constant_value(e))
	case .Variable:
		return fmt.tprintf("%s: %s", it.name, type_string(e.type))
	}
	return it.name
}

group_names :: proc(e: ^doc.Entity) -> []string {
	names := make([dynamic]string, context.temp_allocator)
	for g in doc.from_array(base, e.grouped_entities) {append(&names, str(entities[g].name))}
	return names[:]
}

write_item :: proc(b: ^strings.Builder, it: Item) {
	e := it.entity
	fmt.sbprintf(b, "### %s\n\n", it.name)

	#partial switch e.kind {
	case .Procedure:
		sig := signature(e)
		fmt.sbprintf(b, "```odin\n%s :: %s\n```\n\n", it.name, long_signature(sig))
		write_docs(b, e)
		write_proc_tables(b, sig)
	case .Proc_Group:
		fmt.sbprintf(b, "```odin\n%s\n```\n\n", short_decl(it))
		write_docs(b, e)
		fmt.sbprint(b, "Calls one of these, depending on the argument types:\n\n")
		for g in doc.from_array(base, e.grouped_entities) {
			ge := &entities[g]
			fmt.sbprintf(b, "- %s `%s`\n", link(str(ge.name)), signature(ge).text)
		}
		fmt.sbprint(b, "\n")
	case .Type_Name:
		fmt.sbprintf(b, "```odin\n%s\n```\n\n", type_source(e))
		write_docs(b, e)
		write_type_tables(b, e)
	case:
		fmt.sbprintf(b, "```odin\n%s\n```\n\n", short_decl(it))
		write_docs(b, e)
	}
	fmt.sbprintf(b, "<small>Source: `kiln/%s:%d`</small>\n\n", it.file, e.pos.line)
}

// Doc comments use indented examples; those become Odin code blocks.
write_docs :: proc(b: ^strings.Builder, e: ^doc.Entity) {
	text := strings.trim_right_space(str(e.docs))
	if text == "" {return}
	lines := strings.split_lines(text, context.temp_allocator)
	in_code := false
	for line, i in lines {
		code_line := strings.has_prefix(line, "  ")
		if in_code && strings.trim_space(line) == "" {
			// A blank line inside an example keeps it going if more indented lines follow.
			if i + 1 < len(lines) && strings.has_prefix(lines[i + 1], "  ") {
				fmt.sbprintln(b)
				continue
			}
		}
		if code_line && !in_code {
			fmt.sbprint(b, "\n```odin\n")
			in_code = true
		} else if !code_line && in_code {
			fmt.sbprint(b, "```\n")
			in_code = false
		}
		fmt.sbprintln(b, in_code ? line[2:] : line)
	}
	if in_code {fmt.sbprint(b, "```\n")}
	fmt.sbprint(b, "\n")
}

write_proc_tables :: proc(b: ^strings.Builder, sig: Signature) {
	if len(sig.params) > 0 {
		fmt.sbprint(b, "| Argument | Type | Default |\n| --- | --- | --- |\n")
		for p in sig.params {
			fmt.sbprintf(b, "| `%s` | %s | %s |\n", p.name, type_cell(p.type), p.default == "" ? "required" : code(p.default))
		}
		fmt.sbprint(b, "\n")
	}
	if len(sig.results) > 0 {
		fmt.sbprint(b, "| Returns | Type |\n| --- | --- |\n")
		for r, i in sig.results {
			name := r.name == "" ? fmt.tprintf("#%d", i) : code(r.name)
			fmt.sbprintf(b, "| %s | %s |\n", name, type_cell(r.type))
		}
		fmt.sbprint(b, "\n")
	}
}

write_type_tables :: proc(b: ^strings.Builder, e: ^doc.Entity) {
	bt := base_type(e.type)
	if bt == nil || .Type_Alias in e.flags {return}
	#partial switch bt.kind {
	case .Struct:
		fields := doc.from_array(base, bt.entities)
		if len(fields) == 0 {return}
		fmt.sbprint(b, "| Field | Type | Notes |\n| --- | --- | --- |\n")
		for f in fields {
			fe := &entities[f]
			notes, _ := strings.replace_all(field_notes(fe), "|", "\\|", context.temp_allocator)
			name := str(fe.name)
			if .Param_Using in fe.flags {name = fmt.tprintf("using %s", name)}
			ty := field_type(fe)
			if ty == "" {ty = type_string(fe.type)}
			fmt.sbprintf(b, "| `%s` | %s | %s |\n", name, type_cell(ty), notes)
		}
		fmt.sbprint(b, "\n")
	case .Enum:
		fields := doc.from_array(base, bt.entities)
		if len(fields) == 0 {return}
		fmt.sbprint(b, "Values: ")
		for f, i in fields {
			if i > 0 {fmt.sbprint(b, ", ")}
			fmt.sbprintf(b, "`.%s`", str(entities[f].name))
		}
		fmt.sbprint(b, "\n\n")
	}
}

// Source scanning

// Index of the bracket that closes the one at `open`, skipping strings and comments.
// Scans to the end when it is not closed.
match_close :: proc(s: string, open: int) -> int {
	depth := 0
	for i := open; i < len(s); i += 1 {
		switch s[i] {
		case '(', '[', '{':
			depth += 1
		case ')', ']', '}':
			depth -= 1
			if depth == 0 {return i}
		case '"', '\'', '`':
			i = skip_literal(s, i)
		case '/':
			if i + 1 < len(s) && s[i + 1] == '/' {
				for i < len(s) && s[i] != '\n' {i += 1}
			}
		}
	}
	return len(s)
}

// Index of the closing quote of the literal starting at `i`.
skip_literal :: proc(s: string, i: int) -> int {
	q := s[i]
	for j := i + 1; j < len(s); j += 1 {
		if q != '`' && s[j] == '\\' {
			j += 1
			continue
		}
		if s[j] == q {return j}
	}
	return len(s)
}

// Index of the first of `chars` outside of brackets, strings and comments, or -1.
find_top :: proc(s: string, chars: string, from := 0) -> int {
	for i := from; i < len(s); i += 1 {
		c := s[i]
		if strings.index_byte(chars, c) >= 0 {return i}
		switch c {
		case '(', '[', '{':
			i = match_close(s, i)
		case '"', '\'', '`':
			i = skip_literal(s, i)
		case '/':
			if i + 1 < len(s) && s[i + 1] == '/' {
				for i < len(s) && s[i] != '\n' {i += 1}
				i -= 1
			}
		}
	}
	return -1
}

// Splits at top-level commas and drops comments and empty parts.
split_top :: proc(s: string) -> []string {
	parts := make([dynamic]string, context.temp_allocator)
	rest := s
	for {
		i := find_top(rest, ",")
		part := i < 0 ? rest : rest[:i]
		part = strip_comments(part)
		if part != "" {append(&parts, part)}
		if i < 0 {break}
		rest = rest[i + 1:]
	}
	return parts[:]
}

strip_comments :: proc(s: string) -> string {
	b := strings.builder_make(context.temp_allocator)
	for line in strings.split_lines(s, context.temp_allocator) {
		l := line
		if i := find_top(l, "/"); i >= 0 && i + 1 < len(l) && l[i + 1] == '/' {l = l[:i]}
		fmt.sbprint(&b, l, "")
	}
	return collapse(strings.to_string(b))
}

// Collapses runs of whitespace into single spaces.
collapse :: proc(s: string) -> string {
	b := strings.builder_make(context.temp_allocator)
	space := false
	for c in strings.trim_space(s) {
		if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
			space = true
			continue
		}
		if space {fmt.sbprint(&b, " ")}
		space = false
		fmt.sbprint(&b, c)
	}
	out := strings.to_string(b)
	out, _ = strings.replace_all(out, "( ", "(", context.temp_allocator)
	out, _ = strings.replace_all(out, ", )", ")", context.temp_allocator)
	out, _ = strings.replace_all(out, ",)", ")", context.temp_allocator)
	return out
}

// Parses `a, b: T = x, c := y` into parameters; names without a type take the next one's.
parse_params :: proc(s: string) -> (params: []Param, groups: []string) {
	out := make([dynamic]Param, context.temp_allocator)
	grp := make([dynamic]string, context.temp_allocator)
	pending := make([dynamic]string, context.temp_allocator)
	for part in split_top(s) {
		colon := find_top(part, ":")
		if colon < 0 {
			// A bare name of a group (`lo` in `lo, hi: T`) or an unnamed result type.
			if is_identifier(part) {append(&pending, part)} else {append(&out, Param{"", part, ""})}
			continue
		}
		name := strings.trim_space(part[:colon])
		rest := part[colon + 1:]
		p: Param
		if strings.has_prefix(rest, "=") {
			p.default = strings.trim_space(rest[1:])
		} else if eq := find_top(rest, "="); eq >= 0 {
			p.type = strings.trim_space(rest[:eq])
			p.default = strings.trim_space(rest[eq + 1:])
		} else {
			p.type = strings.trim_space(rest)
		}
		group := strings.join(pending[:], ", ", context.temp_allocator)
		append(&grp, len(pending) > 0 ? fmt.tprintf("%s, %s", group, part) : part)
		for n in pending {append(&out, Param{n, strip_poly(p.type), p.default})}
		clear(&pending)
		p.name = name
		append(&out, p)
	}
	// Results like `-> (int, bool)` are all bare.
	for n in pending {append(&out, Param{"", n, ""})}
	return out[:], grp[:]
}

// `$T` declares T; the names sharing the declaration just use it.
strip_poly :: proc(t: string) -> string {return strings.trim_prefix(t, "$")}

is_identifier :: proc(s: string) -> bool {
	if s == "" {return false}
	for c in s {
		if !(c == '_' || c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9') {return false}
	}
	return !(s[0] >= '0' && s[0] <= '9')
}

// The signature of a procedure from its declaration in the source.
signature :: proc(e: ^doc.Entity) -> Signature {
	src := source_at(e)
	start := strings.index(src, "proc")
	open := start < 0 ? -1 : strings.index_byte(src[start:], '(')
	if open < 0 {return Signature{text = type_string(e.type)}}
	open += start
	close := match_close(src, open)
	params, groups := parse_params(src[open + 1:close])

	// The body starts at the first `{` outside of brackets after the parameters.
	tail_end := find_top(src, "{", close + 1)
	if tail_end < 0 {tail_end = len(src)}
	tail := strings.trim_space(src[close + 1:tail_end])
	results: []Param
	if strings.has_prefix(tail, "->") {
		r := strings.trim_space(tail[2:])
		if strings.has_prefix(r, "(") {
			rc := match_close(r, 0)
			results, _ = parse_params(r[1:rc])
		} else {
			// A single result type, up to `where` or a directive.
			end := len(r)
			if w := strings.index(r, " where "); w >= 0 {end = w}
			if d := strings.index(r, " #"); d >= 0 && d < end {end = d}
			res := make([]Param, 1, context.temp_allocator)
			res[0] = Param{"", strings.trim_space(r[:end]), ""}
			results = res
		}
	}

	// Inferred parameter types (`key := ""`) come from the resolved type.
	resolved := proc_params(e.type)
	for &p in params {
		if p.type != "" {continue}
		for r in resolved {
			if str(entities[r].name) == p.name {p.type = type_string(entities[r].type)}
		}
	}
	for &r in results {
		if r.name == "_" {r.name = ""}
	}

	text := collapse(src[start:tail_end])
	return Signature{text, params, results, groups}
}

proc_params :: proc(ti: doc.Type_Index) -> []doc.Entity_Index {
	if ti == 0 || types[ti].kind != .Proc {return nil}
	ts := doc.from_array(base, types[ti].types)
	if len(ts) < 1 {return nil}
	return doc.from_array(base, types[ts[0]].entities)
}

// The signature on one line, or with one parameter per line when it gets long.
long_signature :: proc(sig: Signature) -> string {
	if len(sig.text) <= 90 || len(sig.groups) == 0 {return sig.text}
	b := strings.builder_make(context.temp_allocator)
	fmt.sbprint(&b, "proc(\n")
	for g in sig.groups {fmt.sbprintf(&b, "\t%s,\n", g)}
	fmt.sbprint(&b, ")")
	// Everything after the parameter list (results, where clauses) stays as it is.
	open := strings.index_byte(sig.text, '(')
	close := match_close(sig.text, open)
	fmt.sbprint(&b, sig.text[close + 1:])
	return strings.to_string(b)
}

// The declaration of a type as written, including the comments on its fields.
type_source :: proc(e: ^doc.Entity) -> string {
	src := source_at(e)
	if src == "" {return fmt.tprintf("%s :: %s", str(e.name), type_string(e.type))}
	end := find_top(src, "{\n")
	if end >= 0 && src[end] == '{' {
		end = match_close(src, end) + 1
	} else if end < 0 {
		end = len(src)
	}
	return strings.trim_right_space(src[:end])
}

// The type of a struct field as written: `chart: [8]Color` gives `[8]Color`, and for the first
// names of a group (`window, sunken: Color`) the type after the colon.
field_type :: proc(e: ^doc.Entity) -> string {
	src := source_at(e)
	colon := find_top(src, ":\n}")
	if colon < 0 || src[colon] != ':' {return ""}
	rest := src[colon + 1:]
	end := find_top(rest, ",\n}=")
	if end < 0 {end = len(rest)}
	return strip_comments(rest[:end])
}

constant_value :: proc(e: ^doc.Entity) -> string {
	init := str(e.init_string)
	if init != "" && len(init) <= 60 && !strings.contains(init, "\n") {return init}
	// Long values (the built-in SVG icons) only show their type.
	return fmt.tprintf("%s{{...}}", type_string(e.type))
}

// Links

// A table cell for a type: kiln types link to their docs.
type_cell :: proc(s: string) -> string {
	name := strings.trim_left(s, "^[]")
	if anchor, ok := anchor_of[name]; ok && is_identifier(name) {
		return fmt.tprintf("%s[`%s`](../%s)", code_prefix(s[:len(s) - len(name)]), name, anchor)
	}
	return code(s)
}

code_prefix :: proc(s: string) -> string {return s == "" ? "" : fmt.tprintf("`%s`", s)}

link :: proc(name: string) -> string {
	if anchor, ok := anchor_of[name]; ok {return fmt.tprintf("[`%s`](../%s)", name, anchor)}
	return code(name)
}

code :: proc(s: string) -> string {
	esc, _ := strings.replace_all(s, "|", "\\|", context.temp_allocator)
	if strings.contains(esc, "`") {return fmt.tprintf("`` %s ``", esc)}
	return fmt.tprintf("`%s`", esc)
}

// Resolved types, for what the source does not spell out

base_type :: proc(ti: doc.Type_Index) -> ^doc.Type {
	if ti == 0 {return nil}
	t := &types[ti]
	if t.kind == .Named {
		ts := doc.from_array(base, t.types)
		if len(ts) == 0 {return nil}
		return &types[ts[0]]
	}
	return t
}

type_string :: proc(ti: doc.Type_Index) -> string {
	if ti == 0 {return ""}
	t := &types[ti]
	ts := doc.from_array(base, t.types)
	#partial switch t.kind {
	case .Basic:
		return str(t.name)
	case .Named:
		name := str(t.name)
		if i := strings.index_byte(name, '('); i >= 0 {name = name[:i]} // Maybe($T=Theme)
		es := doc.from_array(base, t.entities)
		if len(es) > 0 && entities[es[0]].pos.file != 0 {
			// Types of other packages keep their package prefix (`clay.Color`).
			pkg := str(doc.from_array(base, h.pkgs)[files[entities[es[0]].pos.file].pkg].name)
			if pkg != pkg_name && pkg != "builtin" && pkg != "runtime" {
				return fmt.tprintf("%s.%s", pkg, name)
			}
		}
		return name
	case .Generic:
		return fmt.tprintf("$%s", str(t.name))
	case .Pointer:
		return fmt.tprintf("^%s", type_string(ts[0]))
	case .Multi_Pointer:
		return fmt.tprintf("[^]%s", type_string(ts[0]))
	case .Array:
		return fmt.tprintf("[%d]%s", t.elem_counts[0], type_string(ts[0]))
	case .Enumerated_Array:
		return fmt.tprintf("[%s]%s", type_string(ts[0]), type_string(ts[1]))
	case .Slice:
		return fmt.tprintf("[]%s", type_string(ts[0]))
	case .Dynamic_Array:
		return fmt.tprintf("[dynamic]%s", type_string(ts[0]))
	case .Map:
		return fmt.tprintf("map[%s]%s", type_string(ts[0]), type_string(ts[1]))
	case .Bit_Set:
		if len(ts) > 0 {return fmt.tprintf("bit_set[%s]", type_string(ts[0]))}
	case .Proc:
		return "proc(...)"
	case .Struct:
		return "struct {...}"
	case .Union:
		return "union {...}"
	case .Enum:
		return "enum {...}"
	}
	return "?"
}
