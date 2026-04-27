# frozen_string_literal: true

describe Careplus::Client do
  subject(:response) do
    described_class.send_csv(username:, password:, namespace:, payload:)
  end

  let(:base_url) { "http://test.careplus.example.com" }
  let(:username) { "test_user" }
  let(:password) { "test_password" }
  let(:namespace) { "TEST" }
  let(:payload) { "col1,col2\nval1,val2\n" }
  let(:endpoint_path) { "/#{namespace}/soap.SchImms.cls" }
  let(:full_url) { "#{base_url}#{endpoint_path}" }

  before do
    allow(Settings.careplus).to receive(:base_url).and_return(base_url)
    stub_request(:post, full_url).to_return(
      status: 200,
      body: "<result>OK</result>"
    )
  end

  it "sends a POST request to the base URL with the endpoint path" do
    response
    expect(WebMock).to have_requested(:post, full_url)
  end

  it "sets the Content-Type header" do
    response
    expect(WebMock).to have_requested(:post, full_url).with(
      headers: {
        "Content-Type" => "text/xml; charset=utf-8"
      }
    )
  end

  it "includes the username in the SOAP body" do
    response
    expect(WebMock).to have_requested(:post, full_url).with(body: /test_user/)
  end

  it "includes the password in the SOAP body" do
    response
    expect(WebMock).to have_requested(:post, full_url).with(
      body: /test_password/
    )
  end

  it "includes the CSV payload in the SOAP body" do
    response
    expect(WebMock).to have_requested(:post, full_url).with(body: /col1,col2/)
  end

  it "uses the namespace in the SOAP target namespace URI" do
    response
    expect(WebMock).to have_requested(:post, full_url).with(
      body: %r{careplus\.syhapp\.thirdparty\.nhs\.uk/TEST/webservices}
    )
  end

  it "returns the HTTP response" do
    expect(response).to be_a(Net::HTTPSuccess)
  end

  context "when the CSV payload contains XML special characters" do
    let(:payload) { "name\n<Test> & \"School\"\n" }

    it "HTML-escapes the payload before embedding it in the envelope" do
      response
      expect(WebMock).to have_requested(:post, full_url).with(
        body: /&lt;Test&gt; &amp; &quot;School&quot;/
      )
    end
  end

  context "when base_url is not configured" do
    before { allow(Settings.careplus).to receive(:base_url).and_return(nil) }

    it "raises a RuntimeError" do
      expect { response }.to raise_error(RuntimeError)
    end
  end

  context "when base_url uses HTTPS" do
    before do
      allow(Settings.careplus).to receive(:base_url).and_return(
        "https://careplus.example.com"
      )
      stub_request(
        :post,
        "https://careplus.example.com#{endpoint_path}"
      ).to_return(status: 200, body: "")
    end

    it "makes the request over SSL" do
      allow(Net::HTTP).to receive(:new).and_call_original
      response
      expect(Net::HTTP).to have_received(:new).with("careplus.example.com", 443)
    end
  end
end
