@EndUserText.label: 'Promote Employee Parameter'
define abstract entity ZA_HCM_Promote {
  NewPositionId : sysuuid_x16;
  @Semantics.amount.currencyCode: 'CurrencyCode'
  NewSalary     : abap.curr(15,2);
  CurrencyCode  : abap.cuky;
}
