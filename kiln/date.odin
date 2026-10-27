package kiln

// Dates: a plain `Date` with the helpers every app with dates needs, a calendar, and a date
// field that opens the calendar in a popup.
//
//   if d, ok := kiln.date_field(m.due, min = kiln.today()); ok {append(out, Set_Due{d})}
//
// Month and weekday names and the order of the weekdays come from `Metrics.locale`.

import "base:runtime"
import "core:fmt"
import "core:strconv"
import "core:strings"
import "core:time"
import "core:time/datetime"
import "core:time/timezone"
import clay "clay-odin"

// A calendar day. The zero value means "no date".
Date :: struct {
	year, month, day: int, // month 1..12, day 1..31
}

// Names and conventions for dates, part of the theme's metrics.
Locale :: struct {
	months:        [12]string,
	weekdays:      [7]string, // short, Monday first: "Mo", "Tu", ...
	first_weekday: int, // first column of the calendar: 0 = Monday, 6 = Sunday
	date_pattern:  string, // how `date_text` writes a date; YYYY, MM and DD are replaced
}

locale_en :: proc() -> Locale {
	return {
		months = {
			"January",
			"February",
			"March",
			"April",
			"May",
			"June",
			"July",
			"August",
			"September",
			"October",
			"November",
			"December",
		},
		weekdays = {"Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"},
		first_weekday = 0,
		date_pattern = "YYYY-MM-DD",
	}
}

locale_de :: proc() -> Locale {
	return {
		months = {
			"Januar",
			"Februar",
			"März",
			"April",
			"Mai",
			"Juni",
			"Juli",
			"August",
			"September",
			"Oktober",
			"November",
			"Dezember",
		},
		weekdays = {"Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"},
		first_weekday = 0,
		date_pattern = "DD.MM.YYYY",
	}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

date_is_leap :: proc(year: int) -> bool {
	return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

date_days_in_month :: proc(year, month: int) -> int {
	DAYS := [12]int{31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
	if month < 1 || month > 12 {return 0}
	if month == 2 && date_is_leap(year) {return 29}
	return DAYS[month - 1]
}

date_valid :: proc(d: Date) -> bool {
	return d.year > 0 && d.month >= 1 && d.month <= 12 && d.day >= 1 && d.day <= date_days_in_month(d.year, d.month)
}

// Day of the week, 0 = Monday ... 6 = Sunday.
date_weekday :: proc(d: Date) -> int {
	return (days_from_civil(d) + 3) %% 7 // 1970-01-01 was a Thursday
}

date_add_days :: proc(d: Date, n: int) -> Date {
	return civil_from_days(days_from_civil(d) + n)
}

// Moves by whole months and clamps the day: 31 Jan + 1 month = 28 or 29 Feb.
date_add_months :: proc(d: Date, n: int) -> Date {
	total := d.year * 12 + d.month - 1 + n
	r := Date{total / 12, total %% 12 + 1, d.day}
	r.day = clamp(r.day, 1, date_days_in_month(r.year, r.month))
	return r
}

// Days from `a` to `b` (negative if `b` is earlier).
date_diff :: proc(a, b: Date) -> int {
	return days_from_civil(b) - days_from_civil(a)
}

// -1, 0 or 1.
date_compare :: proc(a, b: Date) -> int {
	if a.year != b.year {return a.year < b.year ? -1 : 1}
	if a.month != b.month {return a.month < b.month ? -1 : 1}
	if a.day != b.day {return a.day < b.day ? -1 : 1}
	return 0
}

// Parses "2026-10-26".
date_parse :: proc(s: string) -> (Date, bool) {
	parts := strings.split(strings.trim_space(s), "-", context.temp_allocator)
	if len(parts) != 3 {return {}, false}
	y, ok1 := strconv.parse_int(parts[0], 10)
	m, ok2 := strconv.parse_int(parts[1], 10)
	d, ok3 := strconv.parse_int(parts[2], 10)
	r := Date{y, m, d}
	if !ok1 || !ok2 || !ok3 || !date_valid(r) {return {}, false}
	return r, true
}

// "2026-10-26", in the temp allocator.
date_format :: proc(d: Date) -> string {
	return fmt.tprintf("%04d-%02d-%02d", d.year, d.month, d.day)
}

// The date written with the locale's `date_pattern` ("26.10.2026"), in the temp allocator.
date_text :: proc(d: Date) -> string {
	p := g_theme.locale.date_pattern
	if len(p) == 0 {return date_format(d)}
	s, _ := strings.replace_all(p, "YYYY", fmt.tprintf("%04d", d.year), context.temp_allocator)
	s, _ = strings.replace_all(s, "MM", fmt.tprintf("%02d", d.month), context.temp_allocator)
	s, _ = strings.replace_all(s, "DD", fmt.tprintf("%02d", d.day), context.temp_allocator)
	return s
}

@(private)
g_local_tz: ^datetime.TZ_Region
@(private)
g_local_tz_loaded: bool

// Today in the local time zone.
today :: proc() -> Date {
	dt, ok := time.time_to_datetime(time.now())
	if !ok {return {}}
	if !g_local_tz_loaded {
		g_local_tz, _ = timezone.region_load("local", runtime.heap_allocator())
		g_local_tz_loaded = true
	}
	if g_local_tz != nil {
		if local, local_ok := timezone.datetime_to_tz(dt, g_local_tz); local_ok {dt = local}
	}
	return {int(dt.year), int(dt.month), int(dt.day)}
}

// Days since 1970-01-01 (Howard Hinnant's algorithm, proleptic Gregorian calendar).
@(private)
days_from_civil :: proc(d: Date) -> int {
	y := d.month <= 2 ? d.year - 1 : d.year
	era := (y >= 0 ? y : y - 399) / 400
	yoe := y - era * 400
	doy := (153 * ((d.month + 9) % 12) + 2) / 5 + d.day - 1
	doe := yoe * 365 + yoe / 4 - yoe / 100 + doy
	return era * 146097 + doe - 719468
}

@(private)
civil_from_days :: proc(days: int) -> Date {
	z := days + 719468
	era := (z >= 0 ? z : z - 146096) / 146097
	doe := z - era * 146097
	yoe := (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
	doy := doe - (365 * yoe + yoe / 4 - yoe / 100)
	mp := (5 * doy + 2) / 153
	m := mp < 10 ? mp + 3 : mp - 9
	return {yoe + era * 400 + (m <= 2 ? 1 : 0), m, doy - (153 * mp + 2) / 5 + 1}
}

// Inside the limits; a zero limit means no limit.
@(private)
date_in_range :: proc(d, lo, hi: Date) -> bool {
	return (lo == {} || date_compare(d, lo) >= 0) && (hi == {} || date_compare(d, hi) <= 0)
}

// ---------------------------------------------------------------------------
// Calendar
// ---------------------------------------------------------------------------

// The month a calendar shows and the day the keyboard is on; UI state, kept per calendar.
@(private)
Calendar_State :: struct {
	shown: Date, // day 1 of the shown month
	focus: Date,
	view:  Calendar_View,
	frame: u64,
}

// What a calendar shows: the days of a month, the months of a year, or a page of years. Clicking
// the title goes up (days -> months -> years), picking a year or month goes back down.
@(private)
Calendar_View :: enum {
	Days,
	Months,
	Years,
}

@(private)
YEARS_PER_PAGE :: 12

@(private)
g_calendars: map[u32]Calendar_State

@(private)
calendar_state :: proc(eid: Id, value: Date, restart := false) -> ^Calendar_State {
	st, ok := g_calendars[eid.id]
	if !ok || restart {
		start := date_valid(value) ? value : today()
		st = {shown = {start.year, start.month, 1}, focus = start}
	}
	st.frame = g_frame
	g_calendars[eid.id] = st
	return &g_calendars[eid.id]
}

// A month view to pick a day from. Days outside `min` / `max` (zero = no limit) are drawn faint
// and cannot be picked. While the pointer is over it, the arrow keys move a focus, Page Up /
// Page Down switch the month and Enter picks the focused day.
calendar :: proc(value: Date, min := Date{}, max := Date{}, key := "") -> (Date, bool) {
	eid := id(len(key) > 0 ? key : "calendar")
	st := calendar_state(eid, value)
	result, changed := value, false
	if clay.UI(eid)({layout = {layoutDirection = .TopToBottom, childGap = space(.XS)}}) {
		if d, ok := calendar_body(eid, value, min, max, st, clay.PointerOver(eid)); ok {
			result, changed = d, d != value
		}
	}
	set_last(eid)
	return result, changed
}

// A field showing the date (or the placeholder); a click opens a calendar below it, or above
// when there is no room below. Picking a day closes it.
//
//   if d, ok := kiln.date_field(m.birthday, max = kiln.today()); ok {append(out, Set_Birthday{d})}
date_field :: proc(
	value: Date,
	min := Date{},
	max := Date{},
	placeholder := "",
	disabled := false,
	key := "",
) -> (
	Date,
	bool,
) {
	c := &g_theme
	eid := id(len(key) > 0 ? key : "date_field")
	pop := sub_id(eid, "calendar")
	result, changed := value, false

	s := interact(eid, disabled)
	was_open := popup_is_open(eid)
	if s.clicked {popup_set(eid, !was_open)}
	if disabled {popup_set(eid, false)}
	popup_dismiss(eid, pop)
	open := popup_is_open(eid)
	st := calendar_state(eid, value, restart = open && !was_open) // opens at the value

	h := anim(eid, 0, (s.hovered || open) ? 1 : 0)
	valid := date_valid(value)
	style := font(.Body, (valid && !disabled) ? c.text : c.text_faint)
	style.wrapMode = .None
	border := mix(c.border, c.primary, h)
	if field_error() {border = c.danger}

	if clay.UI(eid)(
	{
		layout = {
			sizing = {clay.SizingGrow(), clay.SizingFixed(size(.Control))},
			padding = inset(.MD, .None),
			childGap = space(.SM),
			childAlignment = {y = .Center},
		},
		backgroundColor = c.sunken,
		cornerRadius = corners(.MD),
		border = outline(border),
		clip = {horizontal = true},
	},
	) {
		clay.TextDynamic(valid ? date_text(value) : placeholder, style)
		spacer()
		clay.TextDynamic("▦", font(.Body, c.text_muted))

		if open {
			old_z := g_z
			g_z = old_z + Z_POPUP
			defer g_z = old_z

			// Open upwards if the calendar does not fit below the field but does above it.
			field := clay.GetElementData(eid).boundingBox
			gap := f32(space(.XS))
			pop_h := 9 * size(.Control)
			if d := clay.GetElementData(pop); d.found {pop_h = d.boundingBox.height}
			below := field.y + field.height + pop_h + gap <= g_in.window.y
			up := !below && field.y - pop_h - gap >= 0

			if clay.UI(pop)(
			{
				layout = {layoutDirection = .TopToBottom, padding = inset(.SM), childGap = space(.XS)},
				backgroundColor = c.surface,
				cornerRadius = corners(.MD),
				border = outline(c.border_strong),
				floating = {
					attachTo = .Parent,
					attachment = up ? {element = .LeftBottom, parent = .LeftTop} : {element = .LeftTop, parent = .LeftBottom},
					offset = {0, up ? -gap : gap},
					zIndex = g_z,
					pointerCaptureMode = .Capture,
				},
			},
			) {
				interact(pop) // clicks between the days stay inside the popup
				if d, ok := calendar_body(eid, value, min, max, st, true); ok {
					result, changed = d, d != value
					popup_set(eid, false)
				}
			}
		}
	}
	set_last(eid, s)
	return result, changed
}

// Header with switching and the cells of the current view: 6 x 7 days (always 6 rows, so the
// height does not change between months), or 4 x 3 months / years in the same height.
// Returns the picked day.
@(private)
calendar_body :: proc(eid: Id, value, lo, hi: Date, st: ^Calendar_State, keys: bool) -> (Date, bool) {
	c := &g_theme
	loc := &g_theme.locale
	picked, ok := Date{}, false

	if keys && g_focus == 0 && st.view == .Days {
		move :: proc(st: ^Calendar_State, d: Date) {
			st.focus = d
			st.shown = {d.year, d.month, 1}
		}
		k := g_in.keys
		if .Left in k {move(st, date_add_days(st.focus, -1))}
		if .Right in k {move(st, date_add_days(st.focus, 1))}
		if .Up in k {move(st, date_add_days(st.focus, -7))}
		if .Down in k {move(st, date_add_days(st.focus, 7))}
		if .Page_Up in k {move(st, date_add_months(st.focus, g_in.shift ? -12 : -1))}
		if .Page_Down in k {move(st, date_add_months(st.focus, g_in.shift ? 12 : 1))}
		if .Enter in k && date_in_range(st.focus, lo, hi) {picked, ok = st.focus, true}
		g_in.keys -= {.Left, .Right, .Up, .Down, .Page_Up, .Page_Down, .Enter} // consumed
	}

	cell := size(.Control)
	cell_h := f32(int(cell * 0.9 + 0.5))
	gap := f32(space(.XS))
	width := 7 * cell
	scope_push(eid) // the buttons get ids of their own per calendar
	defer scope_end()

	// Header: arrows and a title that goes up one view.
	page_start := st.shown.year - st.shown.year %% YEARS_PER_PAGE
	title: string
	switch st.view {
	case .Days:
		title = fmt.tprintf("%s %d", loc.months[clamp(st.shown.month, 1, 12) - 1], st.shown.year)
	case .Months:
		title = fmt.tprint(st.shown.year)
	case .Years:
		title = fmt.tprintf("%d – %d", page_start, page_start + YEARS_PER_PAGE - 1)
	}
	step :: proc(st: ^Calendar_State, dir: int) {
		switch st.view {
		case .Days:
			st.shown = date_add_months(st.shown, dir)
			st.focus = date_add_months(st.focus, dir)
		case .Months:
			st.shown = date_add_months(st.shown, 12 * dir)
		case .Years:
			st.shown = date_add_months(st.shown, 12 * YEARS_PER_PAGE * dir)
		}
	}
	if clay.UI()({layout = {sizing = {clay.SizingFixed(width), clay.SizingFit()}, childAlignment = {y = .Center}}}) {
		if button("‹", .Ghost) {step(st, -1)}
		tid := sub_id(eid, "title")
		up := st.view != .Years
		ts := interact(tid, !up)
		if ts.clicked {st.view = st.view == .Days ? .Months : .Years}
		h := anim(tid, 0, ts.hovered ? 1 : 0)
		if clay.UI(tid)(
		{
			layout = {
				sizing = {clay.SizingGrow(), clay.SizingFixed(size(.Control))},
				childAlignment = {.Center, .Center},
			},
			backgroundColor = mix(fade(c.surface_hover, 0), c.surface_hover, h),
			cornerRadius = corners(.MD),
		},
		) {
			style := font(.Body, c.text)
			style.wrapMode = .None
			clay.TextDynamic(title, style)
			if up {clay.TextDynamic(" ▾", font(.Body, c.text_muted))}
		}
		if button("›", .Ghost) {step(st, 1)}
	}

	if st.view != .Days {
		// 4 rows of 3 in the height of the weekday row and the 6 rows of days.
		total := f32(font_size(.Caption)) + 6 * cell_h + 6 * gap
		row_h := (total - 3 * gap) / 4
		now := today()
		for r in 0 ..< 4 {
			if clay.UI()({layout = {sizing = {clay.SizingFixed(width), clay.SizingFixed(row_h)}}}) {
				for col in 0 ..< 3 {
					i := r * 3 + col
					first, last: Date
					label: string
					selected, current: bool
					if st.view == .Months {
						first = {st.shown.year, i + 1, 1}
						last = {first.year, first.month, date_days_in_month(first.year, first.month)}
						label = loc.months[i]
						selected = value.year == first.year && value.month == first.month
						current = now.year == first.year && now.month == first.month
					} else {
						y := page_start + i
						first, last = {y, 1, 1}, {y, 12, 31}
						label = fmt.tprint(y)
						selected, current = value.year == y, now.year == y
					}
					// Usable if any day of it is inside the limits.
					usable := (lo == {} || date_compare(last, lo) >= 0) && (hi == {} || date_compare(first, hi) <= 0)
					cid := sub_id(eid, st.view == .Months ? "month" : "year", i)
					s := interact(cid, !usable)
					if s.clicked {
						if st.view == .Months {
							st.shown = first
							st.view = .Days
						} else {
							st.shown = {first.year, st.shown.month, 1}
							st.view = .Months
						}
						st.focus = {st.shown.year, st.shown.month, clamp(st.focus.day, 1, date_days_in_month(st.shown.year, st.shown.month))}
					}
					bg: Color
					if s.hovered {bg = c.surface_hover}
					fg := usable ? c.text : fade(c.text_faint, 0.45)
					if selected {bg, fg = c.primary, c.on_primary}
					decl := clay.ElementDeclaration {
						layout = {
							sizing = {clay.SizingPercent(1.0 / 3), clay.SizingGrow()},
							childAlignment = {.Center, .Center},
						},
						backgroundColor = bg,
						cornerRadius = corners(.SM),
					}
					if current {decl.border = outline(c.primary)}
					if clay.UI(cid)(decl) {
						style := font(.Body, fg)
						style.wrapMode = .None
						clay.TextDynamic(label, style)
					}
				}
			}
		}
		return picked, ok
	}

	if clay.UI()({layout = {sizing = {clay.SizingFixed(width), clay.SizingFit()}}}) {
		for i in 0 ..< 7 {
			if clay.UI()({layout = {sizing = {clay.SizingPercent(1.0 / 7), clay.SizingFit()}, childAlignment = {x = .Center}}}) {
				clay.TextDynamic(loc.weekdays[(loc.first_weekday + i) %% 7], font(.Caption, c.text_muted))
			}
		}
	}

	now := today()
	first := st.shown
	day := date_add_days(first, -((date_weekday(first) - loc.first_weekday) %% 7))
	for r in 0 ..< 6 {
		if clay.UI()({layout = {sizing = {clay.SizingFixed(width), clay.SizingFit()}}}) {
			for col in 0 ..< 7 {
				defer day = date_add_days(day, 1)
				cid := sub_id(eid, "day", r * 7 + col)
				usable := date_in_range(day, lo, hi)
				s := interact(cid, !usable)
				if s.clicked {picked, ok = day, true}

				selected := day == value
				outside := day.month != first.month
				bg: Color
				if s.hovered || (keys && day == st.focus) {bg = c.surface_hover}
				fg := outside ? c.text_faint : c.text
				if !usable {fg = fade(c.text_faint, 0.45)}
				if selected {bg, fg = c.primary, c.on_primary}

				decl := clay.ElementDeclaration {
					layout = {
						sizing = {clay.SizingPercent(1.0 / 7), clay.SizingFixed(cell_h)},
						childAlignment = {.Center, .Center},
					},
					backgroundColor = bg,
					cornerRadius = corners(.SM),
				}
				if day == now {decl.border = outline(c.primary)}
				if clay.UI(cid)(decl) {
					style := font(.Body, fg)
					style.wrapMode = .None
					clay.TextDynamic(fmt.tprint(day.day), style)
				}
			}
		}
	}
	return picked, ok
}
