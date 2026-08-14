@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Talent Pool - Projection'
@Metadata.allowExtensions: true
define root view entity ZC_HCM_TalentPool
  provider contract transactional_query
  as projection on ZI_HCM_TalentPool
{
  key PoolId,
  CandidateId,
  FirstName,
  LastName,
  Email,
  Cin,
  ResumeUrl,
  OriginalOffer,
  RejectionReason,
  AddedAt,
  LocalLastChangedAt
}
