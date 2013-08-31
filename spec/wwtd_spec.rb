require "spec_helper"

describe WWTD do
  it "has a VERSION" do
    WWTD::VERSION.should =~ /^[\.\da-z]+$/
  end
end
