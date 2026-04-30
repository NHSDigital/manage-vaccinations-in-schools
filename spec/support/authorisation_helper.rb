# frozen_string_literal: true

module AuthorisationHelper
  def stub_authorization(
    allowed: nil,
    klass: ApplicationPolicy,
    methods: %i[create? new? edit?],
    permissions: nil
  )
    policy_methods = permissions.presence || methods.index_with { allowed }

    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(Pundit::Authorization).to receive(:policy).and_return(
      instance_double(klass, policy_methods)
    )
    # rubocop:enable RSpec/AnyInstance
  end
end
