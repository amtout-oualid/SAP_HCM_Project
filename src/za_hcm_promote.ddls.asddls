@EndUserText.label: 'Promote Employee Parameter'
define abstract entity ZA_HCM_Promote {
  @EndUserText.label: 'New Position'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZC_HCM_Position', element: 'PositionId' } }]
  NewPositionId : sysuuid_x16;
  
  @EndUserText.label: 'New Salary'
  @Semantics.amount.currencyCode: 'CurrencyCode'
  NewSalary     : abap.curr(15,2);
  
  @EndUserText.label: 'Currency'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'I_Currency', element: 'Currency' } }]
  CurrencyCode  : abap.cuky;
}
