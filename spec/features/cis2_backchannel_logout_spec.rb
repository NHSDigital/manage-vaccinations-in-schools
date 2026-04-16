# frozen_string_literal: true

describe "CIS2 backchannel logout", :cis2 do
  scenario "CIS2 sends a logout request" do
    given_the_app_is_setup
    and_that_i_am_signed_in
    and_we_have_a_logout_token
    and_the_jwks_endpoint_is_setup

    when_a_backchannel_signout_request_is_received
    then_returns_a_200
    and_i_try_to_access_the_dashboard
    then_i_am_signed_out

    given_i_wait_a_second
    when_i_sign_in_again
    and_the_backchannel_signout_request_is_replayed
    then_an_error_is_returned

    when_i_try_to_access_the_dashboard
    then_i_see_the_dashboard
  end

  def given_the_app_is_setup
    @team = create(:team, :with_one_nurse)
    create(:gias_school, urn: "123456")
    @user = @team.users.first
  end

  def and_that_i_am_signed_in
    @user.update!(uid: "31337", session_token: SecureRandom.uuid)
    sign_in @user
  end

  alias_method :when_i_sign_in_again, :and_that_i_am_signed_in

  def and_we_have_a_logout_token
    @private_key = OpenSSL::PKey::RSA.generate 2048
    @public_key = @private_key.public_key
    payload = {
      # needs to match issuer in settings
      iss: "http://localhost:4000/test/oidc",
      sub: @user.uid,
      # needs to match cliend_id in settings
      aud: "31337.apps.national",
      iat: Time.zone.now.to_i,
      jti: "bWJq",
      sid: @user.session_token,
      events: {
        "http://schemas.openid.net/event/backchannel-logout": {
        }
      }
    }
    @token = JWT.encode payload, @private_key, "RS256", kid: "key1"
  end

  def and_the_jwks_endpoint_is_setup
    stub_request(
      :get,
      "http://localhost:4000/test/oidc/.well-known/openid-configuration"
    ).to_return(
      status: 200,
      body: { jwks_uri: "http://localhost:4000/test/oidc/jwks" }.to_json
    )

    stub_request(:get, "http://localhost:4000/test/oidc/jwks").to_return(
      status: 200,
      body: {
        keys: [
          {
            kty: "RSA",
            kid: "key1",
            use: "sig",
            n: Base64.urlsafe_encode64(@public_key.n.to_s(2)).tr("=", ""),
            e: Base64.urlsafe_encode64(@public_key.e.to_s(2)).tr("=", ""),
            alg: "RS256"
          }
        ]
      }.to_json
    )
  end

  def given_i_wait_a_second
    travel_to(1.second.from_now)
  end

  def when_a_backchannel_signout_request_is_received
    using_session(:cis2) do
      page.driver.post "/users/auth/cis2/backchannel-logout",
                       logout_token: @token
    end
  end

  alias_method :and_the_backchannel_signout_request_is_replayed,
               :when_a_backchannel_signout_request_is_received

  def then_returns_a_200
    using_session(:cis2) { expect(page.status_code).to eq(200) }
  end

  def then_an_error_is_returned
    using_session(:cis2) { expect(page.status_code).to eq(400) }
  end

  def when_i_try_to_access_the_dashboard
    visit "/dashboard"
  end

  alias_method :and_i_try_to_access_the_dashboard,
               :when_i_try_to_access_the_dashboard

  def then_i_am_signed_out
    expect(page).to have_content "You must be logged in to access this page."
  end

  def then_i_see_the_dashboard
    expect(page).to have_current_path dashboard_path
  end
end
