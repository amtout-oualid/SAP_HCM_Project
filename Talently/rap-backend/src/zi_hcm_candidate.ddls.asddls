@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Candidate - Interface'
define root view entity ZI_HCM_Candidate
  as select from zhcm_candidate
{
  key candidate_id           as CandidateId,
      first_name              as FirstName,
      last_name               as LastName,
      email                  as Email,
      phone                  as Phone,
      cin                    as Cin,
      @Semantics.systemDateTime.createdAt: true
      created_at              as CreatedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at          as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at      as LocalLastChangedAt
}
