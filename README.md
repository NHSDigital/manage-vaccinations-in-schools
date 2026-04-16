# Manage vaccinations in schools

This is a service used within the NHS for managing and recording school-aged vaccinations.

## Environments

| Name                                                                                         | URL                                                                                                      | Purpose                      | Care Identity login | Code                           | Deployment | `RAILS_ENV`                                       |
| -------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ---------------------------- | ------------------- | ------------------------------ | ---------- | ------------------------------------------------- |
| [Test](https://github.com/nhsuk/manage-vaccinations-in-schools/deployments/test)             | [test.mavistesting.com](https://test.mavistesting.com)                                                   | Internal testing (manual)    | ✅                  | `main` branch (latest)         | automated  | [`staging`](config/environments/staging.rb)       |
| [QA](https://github.com/nhsuk/manage-vaccinations-in-schools/deployments/qa)                 | [qa.mavistesting.com](https://qa.mavistesting.com)                                                       | Internal testing (automated) | ❌                  | `main` branch (latest)         | automated  | [`staging`](config/environments/staging.rb)       |
| [Preview](https://github.com/nhsuk/manage-vaccinations-in-schools/deployments/Preview)       | [preview.mavistesting.com](https://preview.mavistesting.com)                                             | External testing             | ❌                  | `release` or release candidate | manual     | [`staging`](config/environments/staging.rb)       |
| [Training](https://github.com/nhsuk/manage-vaccinations-in-schools/deployments/training)     | [training.manage-vaccinations-in-schools.nhs.uk](https://training.manage-vaccinations-in-schools.nhs.uk) | External training            | ❌                  | `release` branch               | manual     | [`staging`](config/environments/staging.rb)       |
| [Production](https://github.com/nhsuk/manage-vaccinations-in-schools/deployments/production) | [www.manage-vaccinations-in-schools.nhs.uk](https://www.manage-vaccinations-in-schools.nhs.uk)           | Live service                 | ✅                  | `release` branch               | manual     | [`production`](config/environments/production.rb) |

## API Documentation

We have two RDoc versions:

1. [next](https://nhsuk.github.io/manage-vaccinations-in-schools/rdoc/next) - useful for dev work (based off the `next` branch).
2. [release](https://nhsuk.github.io/manage-vaccinations-in-schools/rdoc/release) - useful for ops to debug live issues (based off the `release` branch).

## Development

### Prerequisites

This project depends on:

- [Ruby](https://www.ruby-lang.org/)
- [Ruby on Rails](https://rubyonrails.org/)
- [NodeJS](https://nodejs.org/)
- [Yarn](https://yarnpkg.com/)
- [PostgreSQL](https://www.postgresql.org/)
- [Redis](https://redis.io/) or [Valkey](https://valkey.io/)

The instructions below assume you are using `mise` to manage the necessary
versions of the above.

### Application architecture

We keep track of architecture decisions in [Architecture Decision Records
(ADRs)](adr).

We use `rladr` to generate the boilerplate for new records:

```shell
bin/bundle exec rladr new title
```

### Installing dependencies

This project uses `mise`. Use the following to set up (replace `brew` and
package names depending on your platform):

```shell
# Dependencies for ruby
brew install libyaml

# Dependencies for postgres
brew install gcc readline zlib curl ossp-uuid icu4c pkg-config

# Env vars for postgres
export OPENSSL_PATH=$(brew --prefix openssl)
export CMAKE_PREFIX_PATH=$(brew --prefix icu4c)
export PATH="$OPENSSL_PATH/bin:$CMAKE_PREFIX_PATH/bin:$PATH"
export LDFLAGS="-L$OPENSSL_PATH/lib $LDFLAGS"
export CPPFLAGS="-I$OPENSSL_PATH/include $CPPFLAGS"
export PKG_CONFIG_PATH="$CMAKE_PREFIX_PATH/lib/pkgconfig"
export MACOSX_DEPLOYMENT_TARGET="$(sw_vers -productVersion)"

# Version manager
brew install mise
```

Then to install the required tools (or update, following a change to
`.tool-versions`):

```shell
mise install
```

### Background services

For the application to start successfully, PostgreSQL and Redis/Valkey must be
running.

#### PostgreSQL

If using `brew`, the simplest option is to run `brew services start postgresql`.

Alternatively, you can run the server manually:

```shell
pg_ctl start
psql -U postgres -c "CREATE USER $(whoami); ALTER USER $(whoami) WITH SUPERUSER;"
```

#### Redis/Valkey

If using `brew`, the simplest option is to run `brew services start redis`.

Alternatively, you can run the server manually:

```shell
redis-server
```

### Running locally

When running for the first time, `bin/setup` will automatically install Ruby
dependencies and set up the database.

This application also comes with a `Procfile.dev` for use with `foreman` in
development environments. Use the script `bin/dev` to run it:

```shell
$ bin/dev
13:07:31 web.1  | started with pid 73965
13:07:31 css.1  | started with pid 73966
13:07:31 js.1   | started with pid 73967
...
```

### Branching strategy

See the [branching strategy documentation](docs/branching.md) for more information.

### Linting

The linters are configured to run using [`hk`](https://hk.jdx.dev/) which is a tool for running hooks in a Git repository.

If using `mise` this should have already been installed as it's listed in `.tool-versions`, but it can be installed manually by running:

```shell
mise use hk pkl
```

To run the linters you can use `hk check` and `hk fix` to check and fix any linting issues respectively. Alternatively `bin/lint` is provided as a way of running the linters without needing to know about `hk`.

`hk` allows for the linters to be installed as Git hook, ensuring they are run on each commit. This can be configured by running:

```shell
hk install
```

### Intellisense

[solargraph](https://github.com/castwide/solargraph) is bundled as part of the
development dependencies. You need to [set it up for your
editor](https://github.com/castwide/solargraph#using-solargraph), and then run
this command to index your local bundle (re-run if/when we install new
dependencies and you want completion):

```shell
bin/bundle exec yard gems
```

You'll also need to configure your editor's `solargraph` plugin to
`useBundler`:

```diff
+  "solargraph.useBundler": true,
```

### Debugging with `binding.pry`

TTY echo can get mangled when using `binding.pry` in `bin/dev`. To work around
this, you can run `rails s` directly if you're not working with any JS or CSS
assets.

Alternatively, you can install `tmux` and
[`overmind`](https://github.com/DarthSim/overmind#connecting-to-a-process) which
is compatible with our `Procfile.dev`:

```shell
overmind start -f Procfile.dev
overmind connect web
```

### Testing

To run the Rails tests:

```shell
bin/bundle exec rspec
```

or run them in parallel using the `parallel_tests` gem

```shell
# Setup
rake parallel:create parallel:prepare

rake parallel:spec
```

To run the JS unit tests:

```shell
yarn test
```

End-to-end, performance, security and accessibility tests can be found in the [Mavis testing respository](https://github.com/NHSDigital/manage-vaccinations-in-schools-testing). There is also some [additional documentation](https://github.com/NHSDigital/manage-vaccinations-in-schools-testing/tree/main/.github/workflows/) that describes how to run these via GitHub actions.

You can also run the end-to-end tests from this repository:

```shell
bin/e2e tests/test_start.py::test_start_page_elements_visible
```

This requires having the testing repository available locally at `../manage-vaccinations-in-schools-testing`(an alternative location can be used by setting the `MAVIS_E2E_REPO` environment variable) and following the setup steps (installing [uv](https://docs.astral.sh/uv/) and obtaining a .env file).

You can also include the `--main` argument when running tests to force using the latest main version of the testing repo.

This runs tests in the `end_to_end` rails environment which will not interfere with the development server/database. The database needs to be setup in this environment before the tests can be run.

```shell
RAILS_ENV=end_to_end bin/rails db:setup
RAILS_ENV=end_to_end bin/rails feature_flags:enable_for_development
RAILS_ENV=end_to_end bin/mavis gias import --input-file=spec/fixtures/dfe-schools.zip
```

### Example programmes

You can generate an example programme by seeding the database with `rails db:seed:replant`.

### Adding a test user

You can add a new user to an environment using the `users:create` [rake task](docs/rake-tasks.md#userscreateemailpasswordgiven_namefamily_nameteam_ods_code):

```shell

# With no arguments, it will prompt you for all the information it needs:
rails users:create

# Or, create a user belonging to the team with ODS code 'R1L' (this is created in db/seeds.rb):
rails users:create['user@example.com','password123','John', 'Doe','R1L']

# Note that on some Mac machines, this syntax can throw an error saying something like 'zsh: bad pattern', in which case you may need to remove the single quotes and escape the square brackets:
rails users:create\[user@example.com,password123,John,Doe,R1L\]

```

### Previewing view components

[ViewComponent previews](https://viewcomponent.org/guide/previews.html) are enabled in development and test environments. In development, they are here:

    http://localhost:4000/rails/view_components

The previews are defined in `spec/components/previews`.

### Notify

When developing locally, emails are sent using the `:file` delivery method, and
logged to `STDOUT`.

If you want to use Notify, you'll need to set up a test API key, and then set
up a `config/settings/development.local.yml` file:

```yaml
govuk_notify:
  enabled: true
  test_key: YOUR_KEY_HERE
```

You should set it to `enabled: false` when you're done testing Notify locally,
because it's easier to work offline without it.

#### Reply-To

GOV.UK Notify can store reply-to email addresses and use them when sending mail.
Once you've added the reply-to email in GOV.UK Notify, get the UUID and add it to
the team.

### Care Identity Service (CIS2)

This service uses [NHS's CIS2 Care Identity Authentication
service](https://digital.nhs.uk/developer/api-catalogue/nhs-cis2-care-identity-authentication)
to perform OIDC authentication for users.

You can retrieve the issuer URL from the appropriate endpoint listed on [CIS2
Guidance Discovery page]
(https://digital.nhs.uk/services/care-identity-service/applications-and-services/cis2-authentication/guidance-for-developers/detailed-guidance/discovery)
(note: the dev env is being deprecated and will be removed):

```shell
curl -s https://am.nhsint.auth-ptl.cis2.spineservices.nhs.uk/openam/oauth2/realms/root/realms/NHSIdentity/realms/Healthcare/.well-known/openid-configuration | jq .issuer "https://am.nhsint.auth-ptl.cis2.spineservices.nhs.uk:443/openam/oauth2/realms/root/realms/NHSIdentity/realms/Healthcare"
```

Clients in the INT environment can be configured via CIS2 Connection Manager,
please contact other team members to get the details for that. Mavis can
use either a client secret or a private key JWT when authenticating requests to
CIS2, these are configured via the Connection Manager.

To configure Mavis, put non-secret configuration into Settings:

```yaml
cis2:
  enabled: true
  issuer: https://am.nhsint.auth-ptl.cis2.spineservices.nhs.uk/openam/oauth2/realms/root/realms/NHSIdentity/realms/Healthcareopenam/oauth2/realms/root/realms/oidc"
```

And once you have your client secrets, either via the Connection Manager or from
NHS support, put the `client_id` and `secret`/`private_key` into the Rails
credentials file for the environment you are configuring.

```yaml
cis2:
  client_id: # Client ID, as provided by NHS
  secret: # Client secret, as provided by NHS
  private_key: # ... or RSA private key in PEM format
```

The `private_key` will automatically be used to generate a JWK on the
`/oidc/jwks` endpoint, which is used by CIS2 to validate the JWT we use to
request the access token from CIS2.

## Reporting

See [docs/reporting.md](docs/reporting.md).

### Key Rotation

Keys should be rotated regularly. When a new key is introduced it's JWK will
automatically be added to the JWKS generated for `/oidc/jwks`, but the old
public key can also be added to `JWKSController::EXTRA_JWK` to ensure a smooth
roll-over.

## Releasing

See the [releasing documentation](docs/releasing.md) for more information.

## Rake tasks

- `feature_flags:seed`
- `smoke:seed`
- `vaccines:seed[type]`

See the [Rake tasks documentation](docs/rake-tasks.md) for more information.

## Operations tasks

See the [Ops tasks documentation](docs/ops-tasks.md) for more information.

## NHS Personal Demographic Service (PDS) Connection

Mavis is also configured to connect to PDS to retrieve patient information such
as NHS numbers.

See the [PDS documentation](docs/pds.md) for more information.

## Licence

[MIT](LICENCE).
