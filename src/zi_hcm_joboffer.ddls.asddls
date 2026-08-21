@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Job Offer - Interface'
define root view entity ZI_HCM_JobOffer
  as select from zhcm_joboffer
  composition [0..*] of ZI_HCM_PipeTmpl as _Steps
  composition [0..*] of ZI_HCM_Application as _Applications
{
  key offer_id                as OfferId,
      title                   as Title,
      description             as Description,
      department              as Department,
      required_skills         as RequiredSkills,
      experience_level        as ExperienceLevel,
      contract_type           as ContractType,
      location                as Location,
      positions_needed        as PositionsNeeded,
      positions_filled        as PositionsFilled,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      salary_min              as SalaryMin,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      salary_max              as SalaryMax,
      currency_code           as CurrencyCode,
      status                  as Status,
      
      cast( case status
        when 'P' then 'Published'
        when 'C' then 'Closed'
        when 'D' then 'Draft'
        else 'Unknown'
      end as abap.char(20) )  as StatusText,
      
      app_deadline            as AppDeadline, 
      valid_until             as ValidUntil,
      
      /* ADDED THIS FIELD TO FIX ABAP ERROR */
      published_at            as PublishedAt,

      @Semantics.user.createdBy: true
      created_by              as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at              as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by         as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at         as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at   as LocalLastChangedAt,

      _Steps,
      _Applications
}
