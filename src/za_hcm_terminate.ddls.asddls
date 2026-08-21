@EndUserText.label: 'Terminate Employee Parameter'
define abstract entity ZA_HCM_Terminate {
  TerminationDate : abap.dats;
  TerminationReason : abap.char(255);
}
