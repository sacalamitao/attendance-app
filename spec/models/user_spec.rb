require "rails_helper"

RSpec.describe User, type: :model do
  it "defaults to the operator role" do
    expect(create(:user)).to be_operator
  end

  it "supports the admin role" do
    expect(create(:admin)).to be_admin
  end

  it "requires a name and valid email/password" do
    user = described_class.new(email: "bad", password: "short", name: "")
    expect(user).not_to be_valid
    expect(user.errors.attribute_names).to include(:email, :password, :name)
  end

  it "rejects unknown roles" do
    expect(build(:user, role: "superuser")).not_to be_valid
  end
end
