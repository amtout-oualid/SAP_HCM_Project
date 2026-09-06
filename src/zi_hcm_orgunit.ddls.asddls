@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Organizational Unit - Interface'
define root view entity ZI_HCM_OrgUnit
  as select from zhcm_orgunit
  composition [0..*] of ZI_HCM_Position as _Positions
  association [0..1] to ZI_HCM_OrgUnit as _ParentUnit
    on $projection.ParentOrgUnitId = _ParentUnit.OrgUnitId
{
  @UI.hidden: true
  key org_unit_id              as OrgUnitId,
      @EndUserText.label: 'Unit Name'
      unit_name               as UnitName,
      @EndUserText.label: 'Parent Org Unit'
      parent_org_unit_id          as ParentOrgUnitId,
      @EndUserText.label: 'Cost Center'
      cost_center              as CostCenter,
      @EndUserText.label: 'Status'
      status                 as Status,
      @Semantics.user.createdBy: true
      created_by               as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at               as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by            as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at            as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at        as LocalLastChangedAt,

      _Positions,
      _ParentUnit
}
