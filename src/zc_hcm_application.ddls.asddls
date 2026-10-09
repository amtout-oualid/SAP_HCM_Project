@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Application - Projection'
@Metadata.allowExtensions: true
define view entity ZC_HCM_Application
  as projection on ZI_HCM_Application
{
  key ApplicationId,
  OfferId,
  CandidateId,

  @Search.defaultSearchElement: true
  _Candidate.FirstName as CandidateFirstName,

  @Search.defaultSearchElement: true
  _Candidate.LastName  as CandidateLastName,

  @Search.defaultSearchElement: true
  _Candidate.Email     as CandidateEmail,

  ResumeUrl,
  CoverLetter,
  AppliedAt,
  CurrentStepOrder,

  @ObjectModel.text.element: ['OverallStatusText']
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_HCM_VH_AppStatus', element: 'Status' } }]
  @Search.defaultSearchElement: true
  OverallStatus,
  _AppStatus.Description as OverallStatusText,

  StatusCriticality, /* EXPOSED FOR UI COLORING */

  AiMatchScore,
  AiRecommendation,
  AiSummary,
  AiCriticality,
  NoticePeriod,
  @Semantics.amount.currencyCode: 'CurrencyCode'
  SalaryExpectation,
  CurrencyCode,
  RejectionReason,
  InternalNotes,
  @Semantics.systemDateTime.localInstanceLastChangedAt: true
  LocalLastChangedAt,

  /* Associations */
  _Offer : redirected to parent ZC_HCM_JobOffer,
  _Progress : redirected to composition child ZC_HCM_PipeProg,
  _Candidate : redirected to ZC_HCM_Candidate
}
