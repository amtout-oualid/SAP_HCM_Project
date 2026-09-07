@EndUserText.label: 'Transfer Employee Parameter'
define abstract entity ZA_HCM_Transfer {
  @EndUserText.label: 'New Department'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_HCM_OrgUnit', element: 'UnitName' } }]
  NewDepartment : abap.char(40);
}
