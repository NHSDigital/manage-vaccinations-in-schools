# Managing teams

Each SAIS team in Mavis will have their own set of schools, programmes they administer, and in some cases which schools they administer the programmes to and in which year groups.

## Onboarding for the first time

When first onboarding a new SAIS team, there’s a lot of information to include about it. The process involves creating a YAML file containing all the information about the organisation and using the `onboard` Rake task to add everything in to the service.

### Configuration file structure

#### For teams which use Mavis as a point-of-care system

```yaml
organisation:
  ods_code: # ODS code of the organisation

team:
  name: # Unique name of the organisation
  email: # Contact email address
  phone: # Contact phone number
  phone_instructions: # E.g., "option 1, followed by option 3"
  careplus_staff_code: # Staff code used in CarePlus exports
  careplus_staff_type: # Staff type used in CarePlus exports
  careplus_venue_code: # Venue code used in CarePlus exports
  careplus_username: # Optional username for the CarePlus web service
  careplus_password: # Optional password for the CarePlus web service
  privacy_notice_url: # URL of a privacy notice shown to parents
  privacy_policy_url: # URL of a privacy policy shown to parents
  reply_to_id: # Optional GOV.UK Notify Reply-To UUID
  workgroup: # Used in their CIS2 configuration
  type: point_of_care

programmes: [] # A list of programmes (flu, hpv, menacwy, td_ipv, mmr)

subteams:
  subteam1: # Identifier to link team with school and links below, not used in app
    name: # Name of the team
    email: # Contact email address
    phone: # Contact phone number
    phone_instructions: # E.g., "option 9"
    reply_to_id: # Optional GOV.UK Notify Reply-To UUID

schools:
  subteam1:
    - 123456 # Simple URN for a school without sites
    - urn: 234567 # URN for a school with multiple sites
      site: "A" # Site code (A, B, C, etc.)
      name: "School Name (Site A)" # Unique name for this site
    - urn: 234567
      site: "B"
      name: "School Name (Site B)"
      address_line_1: "123 High St" # Optional: override GIAS address
      address_line_2: "Floor 2"
      address_town: "London"
      address_postcode: "SW1A 1AA"

clinics:
  subteam1:
    - name: # Name of the clinic
      address_line_1: # First line of the address
      address_town: # Town of the address
      address_postcode: # Postcode of the address
      ods_code: # Unique ODS code
```

#### For teams which use Mavis for national reporting

These teams need a drastically reduced set of information.

```yaml
organisation:
  ods_code: # ODS code of the organisation

team:
  name: # Unique name of the organisation
  workgroup: # Used in their CIS2 configuration
  type: national_reporting
```

[Example configuration files can be found in the repo][config-onboarding].

[config-onboarding]: /config/onboarding

### Schools and sites

Schools can be added in two ways:

- Simple URN: Just the URN number (e.g., 123456) for schools without multiple sites
- Site object: An object with urn, site, and name for schools that have been split into multiple physical locations

When adding sites:

- urn: The URN of the parent school (must exist in GIAS)
- site: A unique site code (typically A, B, C, etc.)
- name: A unique name for this site (cannot match existing school/site names)

Address fields are optional and will inherit from the parent school if not provided

Note: Schools or sites that are already assigned to another team cannot be onboarded in this way. Thy will have to be added manually (see command below). If a school has been split into sites for one team, it must use the same site structure for all teams.

### Command

Once the file has been written you can use the `onboard` command to set everything up in the service.

```sh
$ bin/mavis teams onboard path/to/configuration.yaml
```

If any validation errors are detected in the file they will be output and nothing will be processed, only if the file is completely valid will anything be processed.

## After onboarding

Once a team has been onboarding, the YAML configuration file can be deleted as it won’t be used again. Instead, a number of command line tools are provided for managing the team.

### Adding new schools to a team

The command `schools add-to-team` is provided to add new schools to an existing team.

```sh
$ bin/mavis schools add-to-team TEAM_WORKGROUP SUBTEAM_NAME URNS
```

- `TEAM_WORKGROUP` refers to the workgroup of the team
- `SUBTEAM_NAME` refers to the name of the subteam in the team
- `URNS` are the URNs of the schools to add

Optionally, it's also possible to customise which programmes are administered at a particular school:

```sh
$ bin/mavis schools add-to-team TEAM_WORKGROUP SUBTEAM_NAME URNS --programmes VALUE1,VALUE2,...
```

### Changing administered year groups of a school

Some SAIS teams will administer certain programmes to certain schools outside the normal year groups. For example, flu is often given at special education needs schools in years 12 and 13.

To modify the year groups per programme per school, the follow two commands are provided:

```sh
$ bin/mavis schools add-programme-year-group URN PROGRAMME_TYPE YEAR_GROUPS
$ bin/mavis schools remove-programme-year-group URN PROGRAMME_TYPE YEAR_GROUPS
```

- `URN` refers to the URN of the school to edit
- `PROGRAMME_TYPE` refers to the programme being edited
- `YEAR_GROUPS` are the year groups to add or remove

### Removing a school from a team

The command `schools add-to-team` is provided to add new schools to an existing team.

```sh
$ bin/mavis schools add-to-team TEAM_WORKGROUP SUBTEAM_NAME URNS
```

- `TEAM_WORKGROUP` refers to the workgroup of the team
- `SUBTEAM_NAME` refers to the name of the subteam in the team
- `URNS` are the URNs of the schools to add
