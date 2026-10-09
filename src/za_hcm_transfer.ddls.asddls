@EndUserText.label: 'Transfer Employee Parameter'
define abstract entity ZA_HCM_Transfer {
  @EndUserText.label: 'New Department'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_HCM_VH_Department', element: 'Department' } }]
  NewDepartment : abap.char(40);
}
