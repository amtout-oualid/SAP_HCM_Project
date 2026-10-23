"! Demo data for the job board: two organizational units with vacant positions and three
"! published job offers linked to those positions. The class only creates new records (nothing
"! is deleted) and goes through the business objects, so every validation and determination runs.
"! Run ZCL_HCM_POPULATE_STATUS first.
CLASS zcl_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun .
ENDCLASS.

CLASS zcl_data IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    DATA(lv_today)    = cl_abap_context_info=>get_system_date( ).
    DATA(lv_deadline) = CONV d( lv_today + 60 ).
    DATA(lv_valid)    = CONV d( lv_today + 90 ).

    " 1. Organizational units with vacant positions (status V is set by the business object)
    MODIFY ENTITIES OF zi_hcm_orgunit
      ENTITY OrgUnit
        CREATE FIELDS ( UnitName Description CostCenter Budget CurrencyCode )
        WITH VALUE #(
          ( %cid = 'ORG_DATA' UnitName = 'Data & AI' Description = 'Data engineering and machine learning'
            CostCenter = 'CC-3000' Budget = '250000' CurrencyCode = 'USD' )
          ( %cid = 'ORG_CS'   UnitName = 'Customer Success' Description = 'Support and customer onboarding'
            CostCenter = 'CC-4000' Budget = '120000' CurrencyCode = 'USD' ) )
        CREATE BY \_Positions
        FIELDS ( JobTitle IsManager FteValue Budget CurrencyCode )
        WITH VALUE #(
          ( %cid_ref = 'ORG_DATA'
            %target  = VALUE #(
              ( %cid = 'POS_DE'  JobTitle = 'Data Engineer'             IsManager = abap_false FteValue = '1.00' Budget = '70000' CurrencyCode = 'USD' )
              ( %cid = 'POS_MLE' JobTitle = 'Machine Learning Engineer' IsManager = abap_false FteValue = '1.00' Budget = '85000' CurrencyCode = 'USD' ) ) )
          ( %cid_ref = 'ORG_CS'
            %target  = VALUE #(
              ( %cid = 'POS_CS1' JobTitle = 'Customer Support Specialist' IsManager = abap_false FteValue = '1.00' Budget = '45000' CurrencyCode = 'USD' )
              ( %cid = 'POS_CS2' JobTitle = 'Customer Support Specialist' IsManager = abap_false FteValue = '1.00' Budget = '45000' CurrencyCode = 'USD' ) ) ) )
      MAPPED DATA(ls_org_mapped)
      FAILED DATA(ls_org_failed).

    IF ls_org_failed IS NOT INITIAL.
      ROLLBACK ENTITIES.
      out->write( 'The organizational units could not be created.' ).
      RETURN.
    ENDIF.

    DATA(lv_pos_de)  = ls_org_mapped-position[ %cid = 'POS_DE' ]-PositionId.
    DATA(lv_pos_mle) = ls_org_mapped-position[ %cid = 'POS_MLE' ]-PositionId.
    DATA(lv_pos_cs)  = ls_org_mapped-position[ %cid = 'POS_CS1' ]-PositionId.

    " 2. Job offers linked to the positions, each with its recruitment pipeline
    MODIFY ENTITIES OF zi_hcm_joboffer
      ENTITY JobOffer
        CREATE FIELDS ( Title Description Department PositionId RequiredSkills ExperienceLevel ContractType
                        Location PositionsNeeded SalaryMin SalaryMax CurrencyCode AppDeadline ValidUntil )
        WITH VALUE #(
          ( %cid = 'JOB_DE' Title = 'Data Engineer' Department = 'Data & AI' PositionId = lv_pos_de
            Description = 'Build and operate the data pipelines that feed our analytics and AI products.'
            RequiredSkills = 'Python, SQL, Apache Spark, ETL, Cloud'
            ExperienceLevel = 'Mid Level' ContractType = 'Full-time' Location = 'Rabat (Hybrid)'
            PositionsNeeded = 1 SalaryMin = '5000' SalaryMax = '7000' CurrencyCode = 'USD'
            AppDeadline = lv_deadline ValidUntil = lv_valid )
          ( %cid = 'JOB_MLE' Title = 'Machine Learning Engineer' Department = 'Data & AI' PositionId = lv_pos_mle
            Description = 'Design, train and deploy machine learning models in production.'
            RequiredSkills = 'Python, PyTorch, MLOps, Docker, Statistics'
            ExperienceLevel = 'Senior Level' ContractType = 'Full-time' Location = 'Remote'
            PositionsNeeded = 1 SalaryMin = '7000' SalaryMax = '10000' CurrencyCode = 'USD'
            AppDeadline = lv_deadline ValidUntil = lv_valid )
          ( %cid = 'JOB_CS' Title = 'Customer Support Specialist' Department = 'Customer Success' PositionId = lv_pos_cs
            Description = 'Help our customers succeed with the product, by chat, e-mail and phone.'
            RequiredSkills = 'Communication, English, French, CRM tools'
            ExperienceLevel = 'Entry Level' ContractType = 'Full-time' Location = 'Casablanca'
            PositionsNeeded = 2 SalaryMin = '2500' SalaryMax = '3500' CurrencyCode = 'USD'
            AppDeadline = lv_deadline ValidUntil = lv_valid ) )
        CREATE BY \_Steps
        FIELDS ( StepOrder StepName StepType StepDescription )
        WITH VALUE #(
          ( %cid_ref = 'JOB_DE'
            %target  = VALUE #(
              ( %cid = 'DE_1' StepOrder = 1 StepName = 'CV Screening'        StepType = 'SCREEN' StepDescription = 'Your resume is reviewed by HR and our AI assistant.' )
              ( %cid = 'DE_2' StepOrder = 2 StepName = 'Technical Test'      StepType = 'TECH'   StepDescription = 'A SQL and Python exercise.' )
              ( %cid = 'DE_3' StepOrder = 3 StepName = 'Final Interview'     StepType = 'INTERV' StepDescription = 'Meet the team lead and HR.' ) ) )
          ( %cid_ref = 'JOB_MLE'
            %target  = VALUE #(
              ( %cid = 'ML_1' StepOrder = 1 StepName = 'CV Screening'        StepType = 'SCREEN' StepDescription = 'Your resume is reviewed by HR and our AI assistant.' )
              ( %cid = 'ML_2' StepOrder = 2 StepName = 'Case Study'          StepType = 'TECH'   StepDescription = 'Present a model you built and its results.' )
              ( %cid = 'ML_3' StepOrder = 3 StepName = 'Final Interview'     StepType = 'INTERV' StepDescription = 'Meet the head of Data & AI.' ) ) )
          ( %cid_ref = 'JOB_CS'
            %target  = VALUE #(
              ( %cid = 'CS_1' StepOrder = 1 StepName = 'CV Screening'        StepType = 'SCREEN' StepDescription = 'Your resume is reviewed by HR.' )
              ( %cid = 'CS_2' StepOrder = 2 StepName = 'HR Interview'        StepType = 'INTERV' StepDescription = 'A short call about your motivation.' ) ) ) )
      MAPPED DATA(ls_job_mapped)
      FAILED DATA(ls_job_failed).

    IF ls_job_failed IS NOT INITIAL.
      ROLLBACK ENTITIES.
      out->write( 'The job offers could not be created.' ).
      RETURN.
    ENDIF.

    " 3. Publication through the business action (status D -> P)
    MODIFY ENTITIES OF zi_hcm_joboffer
      ENTITY JobOffer
        EXECUTE publishOffer
        FROM VALUE #( FOR ls_job IN ls_job_mapped-joboffer ( OfferId = ls_job-OfferId ) )
      FAILED DATA(ls_publish_failed).

    IF ls_publish_failed IS NOT INITIAL.
      ROLLBACK ENTITIES.
      out->write( 'The job offers could not be published.' ).
      RETURN.
    ENDIF.

    " 4. One save for both business objects (validations run here; sy-subrc covers both)
    COMMIT ENTITIES
      RESPONSE OF zi_hcm_joboffer
      FAILED DATA(ls_commit_failed)
      REPORTED DATA(ls_commit_reported).

    IF sy-subrc = 0.
      out->write( 'Demo data created: 2 organizational units, 4 vacant positions, 3 published job offers.' ).
    ELSE.
      out->write( 'The demo data could not be saved:' ).
      LOOP AT ls_commit_reported-joboffer INTO DATA(ls_job_message) WHERE %msg IS BOUND.
        out->write( ls_job_message-%msg->if_message~get_text( ) ).
      ENDLOOP.
      IF ls_commit_failed-joboffer IS INITIAL.
        out->write( 'An organizational unit or position was rejected. Check that ZCL_HCM_POPULATE_STATUS was run.' ).
      ENDIF.
      ROLLBACK ENTITIES.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
