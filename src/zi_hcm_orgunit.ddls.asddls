@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Organizational Unit - Interface'
define root view entity ZI_HCM_OrgUnit
  as select from zhcm_orgunit as Org
  left outer join zhcm_orgunit as Parent on Org.parent_org_unit_id = Parent.org_unit_id
  composition [0..*] of ZI_HCM_Position as _Positions
  association [0..1] to ZI_HCM_OrgUnit as _ParentUnit
    on $projection.ParentOrgUnitId = _ParentUnit.OrgUnitId
{
  @UI.hidden: true
  key Org.org_unit_id              as OrgUnitId,
      @EndUserText.label: 'Org Unit No.'
      Org.org_unit_num            as OrgUnitNum,
      @EndUserText.label: 'Unit Name'
      Org.unit_name               as UnitName,
      @EndUserText.label: 'Description'
      Org.description             as Description,
      @ObjectModel.text.element: ['ParentUnitName']
      @EndUserText.label: 'Parent Org Unit'
      Org.parent_org_unit_id          as ParentOrgUnitId,
      
      Parent.unit_name            as ParentUnitName,
      
      @EndUserText.label: 'Cost Center'
      Org.cost_center              as CostCenter,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      @EndUserText.label: 'Budget'
      Org.budget                 as Budget,
      @EndUserText.label: 'Currency'
      Org.currency_code            as CurrencyCode,
      @EndUserText.label: 'Status'
      Org.status                 as Status,
      @Semantics.user.createdBy: true
      Org.created_by               as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      Org.created_at               as CreatedAt,
      @Semantics.user.lastChangedBy: true
      Org.last_changed_by            as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      Org.last_changed_at            as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      Org.local_last_changed_at        as LocalLastChangedAt,

      _Positions,
      _ParentUnit
}
