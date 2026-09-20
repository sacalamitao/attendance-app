require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#qr_code_svg" do
    it "renders an accessible inline SVG containing only the opaque token" do
      attendee = create(:attendee, full_name: "Grace Lim")
      svg = helper.qr_code_svg(attendee)
      expect(svg).to start_with("<?xml")
      expect(svg).to include("<svg", 'role="img"', "QR code for Grace Lim")
      expect(svg).not_to include(attendee.birthdate.to_s)
    end

    it "escapes the attendee name so it cannot inject SVG attributes" do
      attendee = create(:attendee, full_name: %q{Bad" onload="alert(1)" x="<script>})
      svg = helper.qr_code_svg(attendee)

      # The dangerous forms are the *unescaped* ones that would close the
      # aria-label attribute and start a new one.
      expect(svg).not_to include(%q(onload="))
      expect(svg).not_to include("<script>")
      expect(svg).to include("&quot;")

      root = Nokogiri::XML(svg).root
      expect(root.attributes.keys).to match_array(%w[version viewBox shape-rendering class role aria-label])
      expect(root["onload"]).to be_nil
      expect(root["aria-label"]).to eq("QR code for #{attendee.full_name}")
    end
  end

  describe "#ministry_badge" do
    it "labels known ministries and falls back for blanks" do
      expect(helper.ministry_badge(Ministry::MENS)).to include("Men&#39;s")
      expect(helper.ministry_badge(nil)).to include("—")
    end
  end

  describe "#percentage" do
    it "formats without trailing zeros" do
      expect(helper.percentage(66.7)).to eq("66.7%")
      expect(helper.percentage(100.0)).to eq("100%")
      expect(helper.percentage(0)).to eq("0%")
    end
  end
end
