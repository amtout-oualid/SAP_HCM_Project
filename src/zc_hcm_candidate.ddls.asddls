@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Candidate - Projection'
@Metadata.allowExtensions: true
define root view entity ZC_HCM_Candidate
  provider contract transactional_query
  as projection on ZI_HCM_Candidate
{
  key CandidateId,
  FirstName,
  LastName,
  Email,
  Phone,
  Cin,
  CreatedAt,
  LastChangedAt,
  LocalLastChangedAt
}
