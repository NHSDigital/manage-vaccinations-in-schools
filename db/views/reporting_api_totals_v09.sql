SELECT
  -- Composite key for unique index (required for concurrent refresh)
  pps.patient_id || '-' ||
  pps.programme_type || '-' ||
  tl.team_id || '-' ||
  pl.location_id || '-' ||
  pps.academic_year                       AS id,

  -- Identifiers (for counting and grouping)
  pps.patient_id,                         -- COUNT(DISTINCT patient_id) for totals
  pps.academic_year,                      -- Filter: ?academic_year=2024
  pps.programme_type,                     -- Filter: ?programme=hpv
  pps.status,                             -- Scope: .vaccinated (status IN 60,61)
  pps.consent_status,                     -- Filter: consent dashboard cards
  tl.team_id,                             -- Filter: by user's team_ids
  pl.location_id                          AS session_location_id,  -- Year group eligibility subquery

  -- Patient demographics (used for filtering and CSV grouping)
  CASE pat.gender_code
    WHEN 0 THEN 'not known'
    WHEN 1 THEN 'male'
    WHEN 2 THEN 'female'
    WHEN 9 THEN 'not specified'
    ELSE NULL
  END                                     AS patient_gender,       -- Filter: ?gender=female

  pps.academic_year
    - pat.birth_academic_year - 5         AS patient_year_group,   -- Filter: ?year_group=8,9
  COALESCE(la.mhclg_code,
    pat.local_authority_mhclg_code,
    'UNKNOWN')                            AS patient_local_authority_code,
  COALESCE(la.official_name,
    pat_la.official_name,
    'Unknown Local Authority')            AS patient_local_authority_official_name,
  COALESCE(la.mhclg_code, '')             AS patient_school_local_authority_code,

  -- School info (for CSV grouping by school)
  COALESCE(school.urn, '888888')          AS patient_school_urn,
  COALESCE(school.name, 'Unknown school') AS patient_school_name,

  -- Status flags
  ar.patient_id IS NOT NULL               AS is_archived,  -- Scope: .not_archived

  -- Parent declared "already vaccinated" (counts toward vaccinated total)
  EXISTS (
    SELECT 1 FROM consents con
    WHERE con.patient_id         = pps.patient_id
      AND con.programme_type     = pps.programme_type
      AND con.academic_year      = pps.academic_year
      AND con.invalidated_at     IS NULL
      AND con.withdrawn_at       IS NULL
      AND con.response           = 1  -- refused
      AND con.reason_for_refusal = 1  -- already_vaccinated
  )                                       AS has_already_vaccinated_consent

-- Source: pre-computed patient status per programme/year
FROM patient_programme_statuses pps

-- Patient record (for demographics and exclusion checks)
JOIN patients pat
  ON pat.id = pps.patient_id

-- Where the patient is enrolled this year (links to team via location)
JOIN patient_locations pl
  ON pl.patient_id    = pps.patient_id
 AND pl.academic_year = pps.academic_year

-- Which team owns this location (for team_id filtering)
JOIN team_locations tl
  ON tl.location_id   = pl.location_id
 AND tl.academic_year = pps.academic_year

-- Check if patient is archived by this team (LEFT: most aren't)
LEFT JOIN archive_reasons ar
  ON ar.patient_id = pps.patient_id
 AND ar.team_id    = tl.team_id

-- Patient's school (LEFT: home-educated patients have no school)
LEFT JOIN locations school
  ON school.id = pat.school_id

-- School's local authority (LEFT: school may not have LA set)
LEFT JOIN local_authorities la
  ON la.gias_code = school.gias_local_authority_code

-- Patient's direct local authority (LEFT: fallback when school has no LA)
LEFT JOIN local_authorities pat_la
  ON pat_la.mhclg_code = pat.local_authority_mhclg_code

-- Exclude patients who shouldn't appear in any reports
WHERE pat.invalidated_at IS NULL  -- Merged/duplicate record
  AND pat.restricted_at  IS NULL  -- S31 restricted access
  AND pat.date_of_death  IS NULL  -- Deceased
