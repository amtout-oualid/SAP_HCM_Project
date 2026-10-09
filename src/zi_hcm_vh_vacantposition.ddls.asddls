@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help for Vacant Positions'
@Search.searchable: true
define view entity ZI_HCM_VH_VacantPosition
  as select from zhcm_position as Pos
    left outer join zhcm_orgunit as Org on Pos.org_unit_id = Org.org_unit_id
{
      @ObjectModel.text.element: ['JobTitle']
      @UI.hidden: true
  key Pos.position_id as PositionId,

      @EndUserText.label: 'Job Title'
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      Pos.job_title   as JobTitle,

      @EndUserText.label: 'Organizational Unit'
      @Search.defaultSearchElement: true
      Org.unit_name   as OrgUnitName,

      @EndUserText.label: 'Manager Position'
      Pos.is_manager  as IsManager,

      @EndUserText.label: 'FTE'
      Pos.fte_value   as FteValue
}
where
  Pos.status = 'V'
