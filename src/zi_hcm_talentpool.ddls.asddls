@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Talent Pool - Interface'
define root view entity ZI_HCM_TalentPool
  as select from zhcm_talntpool
{
  key pool_id                as PoolId,
      candidate_id             as CandidateId,
      first_name              as FirstName,
      last_name               as LastName,
      email                  as Email,
      cin                    as Cin,
      resume_url              as ResumeUrl,
      original_offer            as OriginalOffer,
      rejection_reason          as RejectionReason,
      @Semantics.systemDateTime.createdAt: true
      added_at                as AddedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at      as LocalLastChangedAt
}
