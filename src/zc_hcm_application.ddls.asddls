@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Application - Projection'
@Metadata.allowExtensions: true
define view entity ZC_HCM_Application
  as projection on ZI_HCM_Application
{
  key ApplicationId,
  OfferId,
  CandidateId,
  _Candidate.FirstName as CandidateFirstName,
  _Candidate.LastName  as CandidateLastName,
  _Candidate.Email     as CandidateEmail,
  ResumeUrl,
  CoverLetter,
  AppliedAt,
  CurrentStepOrder,
  OverallStatus,
  AiMatchScore,
  NoticePeriod,
  @Semantics.amount.currencyCode: 'CurrencyCode'
  SalaryExpectation,
  CurrencyCode,
  LocalLastChangedAt,
  
  /* Associations */
  _Offer : redirected to parent ZC_HCM_JobOffer,
  _Progress : redirected to composition child ZC_HCM_PipeProg,
  _Candidate : redirected to ZC_HCM_Candidate
}
