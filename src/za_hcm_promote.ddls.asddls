@EndUserText.label: 'Promote Employee Parameter'
define abstract entity ZA_HCM_Promote {
  @EndUserText.label: 'New Position (Vacant)'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_HCM_VH_VacantPosition', element: 'PositionId' } }]
  NewPositionId : sysuuid_x16;

  @EndUserText.label: 'New Salary'
  @Semantics.amount.currencyCode: 'CurrencyCode'
  NewSalary     : abap.curr(15,2);

  @EndUserText.label: 'Currency'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Currency', element: 'Currency' } }]
  CurrencyCode  : abap.cuky;
}
