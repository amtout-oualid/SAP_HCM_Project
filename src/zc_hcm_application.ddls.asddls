@EndUserText.label: 'Job Application - Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
define view entity ZC_HCM_Application
  as projection on ZI_HCM_Application
{
  key ApplicationId,
      @Search.defaultSearchElement: true
      OfferId,
      @Search.defaultSearchElement: true
      CandidateId,
      ResumeUrl,
      CoverLetter,
      AppliedAt,
      CurrentStepOrder,
      OverallStatus,
      AiMatchScore,
      NoticePeriod,
      SalaryExpectation,
      CurrencyCode,
      RejectionReason,
      InternalNotes,
      CandidateFirstName,
      CandidateLastName,
      CandidateEmail,
      LocalLastChangedAt,
      
  /* Associations */
  _Offer : redirected to parent ZC_HCM_JobOffer,
  _Progress : redirected to composition child ZC_HCM_PipeProg,
  _Candidate : redirected to ZC_HCM_Candidate
}
