@EndUserText.label: 'Send Mail Parameter'
define abstract entity ZA_HCM_SendMail {
  MailType : abap.char(30);
  Subject  : abap.char(100);
  Body     : abap.string(1000);
}
