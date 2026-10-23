@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Position - Interface'
define view entity ZI_HCM_Position
  as select from zhcm_position
  association to parent ZI_HCM_OrgUnit as _OrgUnit
    on $projection.OrgUnitId = _OrgUnit.OrgUnitId
  association [0..1] to ZI_HCM_VH_PosStatus as _PosStatus
    on $projection.Status = _PosStatus.Status
{
  @UI.hidden: true
  key position_id              as PositionId,
  @UI.hidden: true
      org_unit_id              as OrgUnitId,
      @EndUserText.label: 'Job Title'
      job_title               as JobTitle,
      @EndUserText.label: 'Is Manager'
      is_manager               as IsManager,
      @EndUserText.label: 'FTE Value'
      fte_value               as FteValue,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      @EndUserText.label: 'Position Budget'
      budget                 as Budget,
      @EndUserText.label: 'Currency'
      currency_code            as CurrencyCode,
      @EndUserText.label: 'Status'
      status                 as Status,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at        as LocalLastChangedAt,

      _OrgUnit,
      _PosStatus
}
