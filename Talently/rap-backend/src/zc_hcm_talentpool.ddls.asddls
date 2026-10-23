@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Talent Pool Projection'
@Metadata.allowExtensions: true
define root view entity ZC_HCM_TALENTPOOL
  provider contract transactional_query
  as projection on ZI_HCM_TALENTPOOL
{
  key PoolId,
  CandidateId,
  OriginalOfferId,
  CandidateName,
  CandidateEmail,
  ResumeUrl,
  AiScore,
  Skills,
  Status,
  AddedAt,
  Notes,
  RejectionReason,
  LastChangedAt
}
