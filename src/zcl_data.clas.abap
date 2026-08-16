CLASS zcl_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_data IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    out->write( 'Starting massive data seed for Cognitus HCM...' ).

    " ======================================================================
    " 1. CREATE ORGANIZATIONAL UNITS & POSITIONS
    " ======================================================================
    MODIFY ENTITIES OF zi_hcm_orgunit
      ENTITY OrgUnit
      CREATE FIELDS ( UnitName CostCenter Status )
      WITH VALUE #(
        ( %cid = 'ORG_GLOBAL' UnitName = 'Cognitus Global Headquarters' CostCenter = 'CC_GL_001' Status = 'A' )
        ( %cid = 'ORG_ENG' UnitName = 'Engineering & Technology' CostCenter = 'CC_EN_002' Status = 'A' )
        ( %cid = 'ORG_CLOUD' UnitName = 'Cloud Infrastructure' CostCenter = 'CC_CL_003' Status = 'A' )
        ( %cid = 'ORG_DATA' UnitName = 'Data & AI Labs' CostCenter = 'CC_DA_004' Status = 'A' )
        ( %cid = 'ORG_PRODUCT' UnitName = 'Product & Design' CostCenter = 'CC_PR_005' Status = 'A' )
        ( %cid = 'ORG_SALES' UnitName = 'Global Sales & Marketing' CostCenter = 'CC_SA_006' Status = 'A' )
        ( %cid = 'ORG_HR' UnitName = 'Human Resources & Talent' CostCenter = 'CC_HR_007' Status = 'A' )
      )
      CREATE BY \_Positions
      FIELDS ( JobTitle IsManager FteValue Status )
      WITH VALUE #(
        ( %cid_ref = 'ORG_ENG' %target = VALUE #(
            ( %cid = 'POS_E1' JobTitle = 'VP of Engineering' IsManager = abap_true FteValue = '1.00' Status = 'F' )
            ( %cid = 'POS_E2' JobTitle = 'Senior Full-Stack Developer' IsManager = abap_false FteValue = '1.00' Status = 'O' )
            ( %cid = 'POS_E3' JobTitle = 'Frontend React Engineer' IsManager = abap_false FteValue = '1.00' Status = 'O' )
            ( %cid = 'POS_E4' JobTitle = 'Backend ABAP RAP Developer' IsManager = abap_false FteValue = '1.00' Status = 'O' )
          )
        )
        ( %cid_ref = 'ORG_CLOUD' %target = VALUE #(
            ( %cid = 'POS_C1' JobTitle = 'Cloud Architect' IsManager = abap_true FteValue = '1.00' Status = 'F' )
            ( %cid = 'POS_C2' JobTitle = 'DevOps Engineer' IsManager = abap_false FteValue = '1.00' Status = 'O' )
            ( %cid = 'POS_C3' JobTitle = 'Site Reliability Engineer' IsManager = abap_false FteValue = '1.00' Status = 'O' )
          )
        )
        ( %cid_ref = 'ORG_DATA' %target = VALUE #(
            ( %cid = 'POS_D1' JobTitle = 'Director of AI' IsManager = abap_true FteValue = '1.00' Status = 'O' )
            ( %cid = 'POS_D2' JobTitle = 'Data Scientist' IsManager = abap_false FteValue = '1.00' Status = 'O' )
            ( %cid = 'POS_D3' JobTitle = 'Machine Learning Engineer' IsManager = abap_false FteValue = '1.00' Status = 'O' )
            ( %cid = 'POS_D4' JobTitle = 'Data Engineer' IsManager = abap_false FteValue = '1.00' Status = 'O' )
          )
        )
      )
      FAILED DATA(failed_org).

    " ======================================================================
    " 2. CREATE JOB OFFERS & PIPELINES
    " ======================================================================
    MODIFY ENTITIES OF zi_hcm_joboffer
      ENTITY JobOffer
      CREATE FIELDS ( Title Department Location ContractType ExperienceLevel SalaryMin SalaryMax CurrencyCode PositionsNeeded Status ValidUntil )
      WITH VALUE #(
        ( %cid = 'JOB1' Title = 'Senior Full-Stack Developer' Department = 'Engineering' Location = 'Remote, USA'
          ContractType = 'CDI' ExperienceLevel = 'Senior' SalaryMin = '9000' SalaryMax = '12000'
          CurrencyCode = 'USD' PositionsNeeded = 3 Status = 'P' ValidUntil = '20261231' )

        ( %cid = 'JOB2' Title = 'Cloud DevOps Engineer' Department = 'Infrastructure' Location = 'New York, USA'
          ContractType = 'CDI' ExperienceLevel = 'Mid' SalaryMin = '8000' SalaryMax = '10000'
          CurrencyCode = 'USD' PositionsNeeded = 2 Status = 'P' ValidUntil = '20261130' )

        ( %cid = 'JOB3' Title = 'UI/UX Product Designer' Department = 'Design' Location = 'San Francisco, USA (Hybrid)'
          ContractType = 'CDD' ExperienceLevel = 'Mid' SalaryMin = '6500' SalaryMax = '8500'
          CurrencyCode = 'USD' PositionsNeeded = 1 Status = 'P' ValidUntil = '20261015' )

        ( %cid = 'JOB4' Title = 'Director of AI Labs' Department = 'Data' Location = 'Boston, USA'
          ContractType = 'CDI' ExperienceLevel = 'Lead / Manager' SalaryMin = '15000' SalaryMax = '20000'
          CurrencyCode = 'USD' PositionsNeeded = 1 Status = 'P' ValidUntil = '20261201' )

        ( %cid = 'JOB5' Title = 'Frontend React Engineer' Department = 'Engineering' Location = 'Berlin, Germany'
          ContractType = 'CDI' ExperienceLevel = 'Entry' SalaryMin = '4000' SalaryMax = '5500'
          CurrencyCode = 'EUR' PositionsNeeded = 5 Status = 'P' ValidUntil = '20260930' )

        ( %cid = 'JOB6' Title = 'Backend ABAP RAP Developer' Department = 'Engineering' Location = 'Walldorf, Germany'
          ContractType = 'CDI' ExperienceLevel = 'Senior' SalaryMin = '7000' SalaryMax = '9500'
          CurrencyCode = 'EUR' PositionsNeeded = 2 Status = 'P' ValidUntil = '20261031' )

        ( %cid = 'JOB7' Title = 'Site Reliability Engineer (SRE)' Department = 'Infrastructure' Location = 'London, UK'
          ContractType = 'CDI' ExperienceLevel = 'Mid' SalaryMin = '6000' SalaryMax = '8000'
          CurrencyCode = 'GBP' PositionsNeeded = 2 Status = 'P' ValidUntil = '20261115' )

        ( %cid = 'JOB8' Title = 'Machine Learning Engineer' Department = 'Data' Location = 'Remote, Global'
          ContractType = 'Contract' ExperienceLevel = 'Mid' SalaryMin = '7000' SalaryMax = '11000'
          CurrencyCode = 'USD' PositionsNeeded = 4 Status = 'P' ValidUntil = '20261231' )

        ( %cid = 'JOB9' Title = 'Data Engineer' Department = 'Data' Location = 'Toronto, USA'
          ContractType = 'CDI' ExperienceLevel = 'Junior' SalaryMin = '5000' SalaryMax = '7000'
          CurrencyCode = 'USD' PositionsNeeded = 2 Status = 'P' ValidUntil = '20261020' )

        ( %cid = 'JOB10' Title = 'HR Talent Acquisition Specialist' Department = 'Human Resources' Location = 'Chicago, USA'
          ContractType = 'CDD' ExperienceLevel = 'Mid' SalaryMin = '4500' SalaryMax = '6000'
          CurrencyCode = 'USD' PositionsNeeded = 1 Status = 'P' ValidUntil = '20260915' )

        ( %cid = 'JOB11' Title = 'IT Support Technician' Department = 'Infrastructure' Location = 'Austin, USA'
          ContractType = 'Intern' ExperienceLevel = 'Entry' SalaryMin = '2000' SalaryMax = '3000'
          CurrencyCode = 'USD' PositionsNeeded = 3 Status = 'P' ValidUntil = '20260831' )

        ( %cid = 'JOB12' Title = 'Enterprise Sales Executive' Department = 'Sales' Location = 'Remote, EMEA'
          ContractType = 'CDI' ExperienceLevel = 'Senior' SalaryMin = '8000' SalaryMax = '12000'
          CurrencyCode = 'EUR' PositionsNeeded = 2 Status = 'P' ValidUntil = '20261231' )
      )
      CREATE BY \_Steps
      FIELDS ( StepName StepType StepOrder )
      WITH VALUE #(
        ( %cid_ref = 'JOB1' %target = VALUE #(
            ( %cid = 'J1S1' StepOrder = 1 StepName = 'CV Screening' StepType = 'SCREENING' )
            ( %cid = 'J1S2' StepOrder = 2 StepName = 'Technical Problem Solving' StepType = 'TEST' )
            ( %cid = 'J1S3' StepOrder = 3 StepName = 'HR Interview' StepType = 'MEETING' )
            ( %cid = 'J1S4' StepOrder = 4 StepName = 'System Design Interview' StepType = 'MEETING' )
          )
        )
        ( %cid_ref = 'JOB2' %target = VALUE #(
            ( %cid = 'J2S1' StepOrder = 1 StepName = 'CV Screening' StepType = 'SCREENING' )
            ( %cid = 'J2S2' StepOrder = 2 StepName = 'AWS Architecture Test' StepType = 'TEST' )
            ( %cid = 'J2S3' StepOrder = 3 StepName = 'Technical Interview' StepType = 'MEETING' )
          )
        )
        ( %cid_ref = 'JOB3' %target = VALUE #(
            ( %cid = 'J3S1' StepOrder = 1 StepName = 'Portfolio Review' StepType = 'SCREENING' )
            ( %cid = 'J3S2' StepOrder = 2 StepName = 'Figma Design Challenge' StepType = 'TEST' )
            ( %cid = 'J3S3' StepOrder = 3 StepName = 'Culture Fit Interview' StepType = 'MEETING' )
          )
        )
        ( %cid_ref = 'JOB4' %target = VALUE #(
            ( %cid = 'J4S1' StepOrder = 1 StepName = 'Executive Screening' StepType = 'SCREENING' )
            ( %cid = 'J4S2' StepOrder = 2 StepName = 'Leadership Interview' StepType = 'MEETING' )
            ( %cid = 'J4S3' StepOrder = 3 StepName = 'Panel Presentation' StepType = 'MEETING' )
          )
        )
        ( %cid_ref = 'JOB5' %target = VALUE #(
            ( %cid = 'J5S1' StepOrder = 1 StepName = 'CV Screening' StepType = 'SCREENING' )
            ( %cid = 'J5S2' StepOrder = 2 StepName = 'React Coding Challenge' StepType = 'TEST' )
            ( %cid = 'J5S3' StepOrder = 3 StepName = 'Pair Programming' StepType = 'TEST' )
            ( %cid = 'J5S4' StepOrder = 4 StepName = 'Final Interview' StepType = 'MEETING' )
          )
        )
        ( %cid_ref = 'JOB6' %target = VALUE #(
            ( %cid = 'J6S1' StepOrder = 1 StepName = 'CV Screening' StepType = 'SCREENING' )
            ( %cid = 'J6S2' StepOrder = 2 StepName = 'ABAP RAP Concepts' StepType = 'TEST' )
            ( %cid = 'J6S3' StepOrder = 3 StepName = 'Technical Interview' StepType = 'MEETING' )
          )
        )
        ( %cid_ref = 'JOB8' %target = VALUE #(
            ( %cid = 'J8S1' StepOrder = 1 StepName = 'CV Screening' StepType = 'SCREENING' )
            ( %cid = 'J8S2' StepOrder = 2 StepName = 'Python/PyTorch Test' StepType = 'TEST' )
            ( %cid = 'J8S3' StepOrder = 3 StepName = 'Model Deployment Interview' StepType = 'MEETING' )
          )
        )
      )
      FAILED DATA(failed_job).

    " ======================================================================
    " 3. CREATE EMPLOYEES (WORKERS)
    " ======================================================================
    MODIFY ENTITIES OF zi_hcm_employee
      ENTITY Employee
      CREATE FIELDS ( FirstName LastName DateOfBirth PlaceOfBirth Nationality Gender EmployeeStatus )
      WITH VALUE #(
        ( %cid = 'EMP1' FirstName = 'Sarah' LastName = 'Connor' DateOfBirth = '19850512' PlaceOfBirth = 'Los Angeles' Nationality = 'US' Gender = 'Female' EmployeeStatus = 'A' )
        ( %cid = 'EMP2' FirstName = 'Michael' LastName = 'Chang' DateOfBirth = '19920822' PlaceOfBirth = 'San Francisco' Nationality = 'US' Gender = 'Male' EmployeeStatus = 'A' )
        ( %cid = 'EMP3' FirstName = 'Elena' LastName = 'Rodriguez' DateOfBirth = '19881130' PlaceOfBirth = 'Madrid' Nationality = 'ES' Gender = 'Female' EmployeeStatus = 'A' )
        ( %cid = 'EMP4' FirstName = 'David' LastName = 'Kim' DateOfBirth = '19950214' PlaceOfBirth = 'Seoul' Nationality = 'KR' Gender = 'Male' EmployeeStatus = 'A' )
      )
      CREATE BY \_Contact
      FIELDS ( PersonalAddress PhoneNumber PersonalEmail WorkEmail )
      WITH VALUE #(
        ( %cid_ref = 'EMP1' %target = VALUE #( ( %cid = 'EMP1_C' PersonalAddress = '123 Tech Blvd, LA' PhoneNumber = '+1 555-0101' PersonalEmail = 'sarah.c@gmail.com' WorkEmail = 'sarah.connor@cognitus.com' ) ) )
        ( %cid_ref = 'EMP2' %target = VALUE #( ( %cid = 'EMP2_C' PersonalAddress = '456 Bay Area, SF' PhoneNumber = '+1 555-0102' PersonalEmail = 'm.chang92@yahoo.com' WorkEmail = 'michael.chang@cognitus.com' ) ) )
        ( %cid_ref = 'EMP3' %target = VALUE #( ( %cid = 'EMP3_C' PersonalAddress = '789 Gran Via, Madrid' PhoneNumber = '+34 600-0103' PersonalEmail = 'elena.r@hotmail.com' WorkEmail = 'elena.rodriguez@cognitus.com' ) ) )
        ( %cid_ref = 'EMP4' %target = VALUE #( ( %cid = 'EMP4_C' PersonalAddress = '321 Gangnam, Seoul' PhoneNumber = '+82 10-0104' PersonalEmail = 'david.kim95@naver.com' WorkEmail = 'david.kim@cognitus.com' ) ) )
      )
      CREATE BY \_BankDetails
      FIELDS ( BankName AccountNumber Iban )
      WITH VALUE #(
        ( %cid_ref = 'EMP1' %target = VALUE #( ( %cid = 'EMP1_B' BankName = 'Bank of America' AccountNumber = '100200300' Iban = 'US12BOFA100200300' ) ) )
        ( %cid_ref = 'EMP2' %target = VALUE #( ( %cid = 'EMP2_B' BankName = 'Chase Bank' AccountNumber = '400500600' Iban = 'US34CHAS400500600' ) ) )
      )
      FAILED DATA(failed_emp).

    COMMIT ENTITIES.

    IF failed_job IS NOT INITIAL OR failed_org IS NOT INITIAL OR failed_emp IS NOT INITIAL.
      out->write( 'Error creating dummy data. Check logs.' ).
    ELSE.
      out->write( 'Successfully created 12 Job Offers, pipelines, 7 Org Units, and Employees (Workers)!' ).
    ENDIF.

  ENDMETHOD.
ENDCLASS.
