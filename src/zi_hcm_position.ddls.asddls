@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Position - Interface'
define view entity ZI_HCM_Position
  as select from zhcm_position
  association to parent ZI_HCM_OrgUnit as _OrgUnit
    on $projection.OrgUnitId = _OrgUnit.OrgUnitId
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
      @EndUserText.label: 'Status'
      status                 as Status,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at        as LocalLastChangedAt,

      _OrgUnit
}
