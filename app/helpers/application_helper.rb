module ApplicationHelper
  INPUT_CLASSES = "block w-full rounded-lg border border-slate-300 bg-white px-3 py-2.5 text-base text-slate-900 shadow-sm placeholder:text-slate-400 focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-200 disabled:bg-slate-100".freeze
  LABEL_CLASSES = "block text-sm font-medium text-slate-700 mb-1".freeze
  BUTTON_BASE = "inline-flex items-center justify-center gap-2 rounded-lg px-4 py-2.5 text-sm font-semibold shadow-sm transition focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed".freeze
  BUTTON_VARIANTS = {
    primary: "bg-indigo-600 text-white hover:bg-indigo-700 focus-visible:ring-indigo-500",
    secondary: "bg-white text-slate-700 border border-slate-300 hover:bg-slate-50 focus-visible:ring-indigo-500",
    success: "bg-emerald-600 text-white hover:bg-emerald-700 focus-visible:ring-emerald-500",
    danger: "bg-rose-600 text-white hover:bg-rose-700 focus-visible:ring-rose-500",
    ghost: "text-slate-600 hover:bg-slate-100 shadow-none focus-visible:ring-indigo-500"
  }.freeze

  MINISTRY_BADGE_CLASSES = {
    Ministry::KKB => "bg-sky-100 text-sky-800 ring-sky-200",
    Ministry::YAN => "bg-violet-100 text-violet-800 ring-violet-200",
    Ministry::MENS => "bg-amber-100 text-amber-800 ring-amber-200",
    Ministry::WOMENS => "bg-pink-100 text-pink-800 ring-pink-200"
  }.freeze

  STATUS_BADGE_CLASSES = {
    "draft" => "bg-slate-100 text-slate-700 ring-slate-200",
    "open" => "bg-emerald-100 text-emerald-800 ring-emerald-200",
    "closed" => "bg-slate-800 text-white ring-slate-700"
  }.freeze

  def page_title(title)
    content_for(:title, title)
    title
  end

  def input_classes(extra = nil)
    [ INPUT_CLASSES, extra ].compact.join(" ")
  end

  def label_classes
    LABEL_CLASSES
  end

  def button_classes(variant = :primary, extra = nil)
    [ BUTTON_BASE, BUTTON_VARIANTS.fetch(variant), extra ].compact.join(" ")
  end

  def ministry_badge(code, size: :sm)
    return tag.span("—", class: "text-slate-400") if code.blank?

    classes = MINISTRY_BADGE_CLASSES.fetch(code.to_s, "bg-slate-100 text-slate-700 ring-slate-200")
    padding = size == :lg ? "px-3 py-1 text-base" : "px-2 py-0.5 text-xs"
    tag.span(Ministry.label(code), class: "inline-flex items-center rounded-full font-semibold ring-1 ring-inset #{padding} #{classes}")
  end

  def event_status_badge(event)
    classes = STATUS_BADGE_CLASSES.fetch(event.status, "bg-slate-100 text-slate-700")
    tag.span(event.status.titleize, class: "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-semibold ring-1 ring-inset #{classes}")
  end

  def attendee_status_badge(attendee)
    if attendee.active?
      tag.span("Active", class: "inline-flex items-center rounded-full bg-emerald-100 px-2 py-0.5 text-xs font-semibold text-emerald-800 ring-1 ring-inset ring-emerald-200")
    else
      tag.span("Inactive", class: "inline-flex items-center rounded-full bg-slate-100 px-2 py-0.5 text-xs font-semibold text-slate-600 ring-1 ring-inset ring-slate-200")
    end
  end

  def percentage(value)
    "#{number_with_precision(value, precision: 1, strip_insignificant_zeros: true)}%"
  end

  def nav_link_to(name, path, icon: nil)
    active = current_page?(path) || (path != root_path && request.path.start_with?(path))
    classes = active ? "bg-indigo-700/60 text-white" : "text-indigo-100 hover:bg-indigo-700/40 hover:text-white"
    link_to path, class: "rounded-md px-3 py-2 text-sm font-medium #{classes}", "aria-current": (active ? "page" : nil) do
      safe_join([ (icon ? tag.span(icon, class: "mr-1", "aria-hidden": true) : nil), name ].compact)
    end
  end

  # Inline SVG QR code for an attendee. The image encodes only the opaque token.
  #
  # rqrcode interpolates svg_attributes verbatim and we mark the result
  # html_safe, so the attendee-supplied name MUST be escaped here or a name
  # containing a quote would inject arbitrary SVG attributes.
  def qr_code_svg(attendee, module_size: 6)
    label = ERB::Util.html_escape("QR code for #{attendee.full_name}")
    RQRCode::QRCode.new(attendee.qr_payload).as_svg(
      module_size: module_size, standalone: true, use_path: true, viewbox: true,
      svg_attributes: { class: "h-auto w-full max-w-xs", role: "img", "aria-label": label }
    ).html_safe
  end

  def form_errors(record)
    return if record.errors.empty?

    tag.div(class: "rounded-lg border border-rose-200 bg-rose-50 p-4 text-sm text-rose-800", role: "alert") do
      safe_join([
        tag.p("Please fix the following #{pluralize(record.errors.count, 'problem')}:", class: "font-semibold"),
        tag.ul(safe_join(record.errors.full_messages.map { |m| tag.li(m) }), class: "mt-1 list-disc pl-5")
      ])
    end
  end

  def scan_time(time)
    l(time, format: :time)
  end
end
