@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Position - Interface'
define view entity ZI_HCM_Position
  as select from zhcm_position
  association to parent ZI_HCM_OrgUnit as _OrgUnit
    on $projection.OrgUnitId = _OrgUnit.OrgUnitId
{
  key position_id              as PositionId,
      org_unit_id              as OrgUnitId,
      job_title               as JobTitle,
      is_manager               as IsManager,
      fte_value               as FteValue,
      status                 as Status,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at        as LocalLastChangedAt,

      _OrgUnit
}
