import axios from 'axios';

// The SAP API base path for the UI service
const sapPath = '/sap/opu/odata4/sap/zui_hcm_recruit/srvd/sap/zui_hcm_recruit/0001';

const api = axios.create({
  baseURL: `/sap-api${sapPath}`,
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  }
});

/**
 * Fetch all published job offers
 */
export const fetchJobsFromSAP = async (userEmail) => {
  try {
    const response = await api.get("/JobOffer?$filter=Status ne 'D' and IsActiveEntity eq true&$expand=_Steps,_Applications($expand=_Candidate)");
    console.log("SAP API Response:", response.data);
    
    if (!response.data.value) {
      console.error("SAP API did not return a value array! Response was:", response.data);
      return [];
    }

    // Map SAP fields to Frontend expected fields
    const mappedJobs = response.data.value.map(job => {
      let hasApplied = false;
      let currentStepOrder = 1;
      let applicationStatus = 'NW';
      let applicationId = null;
      
      if (userEmail && job._Applications && job._Applications.length > 0) {
        // Check if any application belongs to the current user's email
        const userApp = job._Applications.find(app => app._Candidate && app._Candidate.Email && app._Candidate.Email.toLowerCase() === userEmail.toLowerCase());
        if (userApp) {
          hasApplied = true;
          currentStepOrder = userApp.CurrentStepOrder || 1;
          applicationStatus = userApp.OverallStatus || 'NW';
          applicationId = userApp.ApplicationId;
        }
      }

      // Sort _Steps by StepOrder if they exist
      let steps = [];
      if (job._Steps && job._Steps.length > 0) {
        steps = job._Steps.sort((a, b) => a.StepOrder - b.StepOrder).map(s => ({
          name: s.StepName,
          description: s.StepDescription || "You are progressing through the evaluation pipeline."
        }));
      }
      
      // Compute Progress string
      let progress = steps.length > 0 ? (steps[currentStepOrder - 1]?.name || steps[0]?.name) : 'Screening';

      // Map raw SAP values strictly to UI expected values
      let contractType = job.ContractType || 'Full-time';
      if (contractType.toLowerCase() === 'full-time') contractType = 'Full-time';
      if (contractType.toLowerCase() === 'part-time') contractType = 'Part-time';

      let experienceLevel = job.ExperienceLevel || 'Mid Level';
      if (experienceLevel.toLowerCase() === 'senior') experienceLevel = 'Senior Level';
      if (experienceLevel.toLowerCase() === 'mid-level') experienceLevel = 'Mid Level';
      if (experienceLevel.toLowerCase() === 'entry-level' || experienceLevel.toLowerCase() === 'junior') experienceLevel = 'Entry Level';
      if (experienceLevel.toLowerCase() === 'lead' || experienceLevel.toLowerCase() === 'manager') experienceLevel = 'Lead / Manager';
      // WorkType in UI is derived from Location if not explicitly defined in SAP, or just assume from Location text
      let workType = 'On-site';
      if ((job.Location || '').toLowerCase().includes('remote')) workType = 'Remote';
      if ((job.Location || '').toLowerCase().includes('hybrid')) workType = 'Hybrid';

      const sMin = parseFloat(job.SalaryMin);
      const sMax = parseFloat(job.SalaryMax);
      const parsedSalaryMin = isNaN(sMin) ? 0 : sMin;
      const parsedSalaryMax = isNaN(sMax) ? 0 : sMax;

      // Handle SAP date strings
      // PublishedAt in SAP backend is often a TIMS time string (e.g. 23:49:56 or 00:00:00).
      // CreatedAt is the actual ISO timestamp (e.g. 2026-09-07T22:04:15Z).
      let validDate = null;
      if (job.CreatedAt && job.CreatedAt !== '00:00:00' && job.CreatedAt !== '0000-00-00') {
        validDate = job.CreatedAt;
      } else if (job.PublishedAt && job.PublishedAt.includes('-')) {
        validDate = job.PublishedAt;
      } else {
        validDate = new Date().toISOString();
      }

      return {
        OfferId: job.OfferId,
        Title: job.Title,
        Department: job.Department,
        Location: job.Location,
        Description: job.Description,
        SalaryMin: parsedSalaryMin, 
        SalaryMax: parsedSalaryMax,
        AnnualSalaryMin: parsedSalaryMin * 12,
        AnnualSalaryMax: parsedSalaryMax * 12,
        CurrencyCode: job.CurrencyCode || 'USD',
        ContractType: contractType,
        Company: job.Department || "Talently", // Use Department as Company name placeholder since HR is internal
        Date: validDate,
        CreatedAt: validDate,
        PublishedAt: validDate,
        AppDeadline: job.AppDeadline,
        ExperienceLevel: experienceLevel,
        WorkType: workType,
        RequiredSkills: job.RequiredSkills ? job.RequiredSkills.split(',').map(s => s.trim()) : [],
        PositionsNeeded: job.PositionsNeeded || 1,
        PositionsFilled: job.PositionsFilled || 0,
        hasApplied: hasApplied,
        ApplicationStatus: applicationStatus,
        ApplicationId: applicationId,
        CurrentStepOrder: currentStepOrder,
        Progress: progress,
        Steps: steps,
        ValidUntil: job.ValidUntil,
        _ApplicationsCount: job._Applications ? job._Applications.length : 0,
        _rawStatus: job.Status
      };
    });

    // Deduplicate jobs by OfferId to prevent React key warnings in case the backend returns joined duplicates
    const uniqueJobs = [];
    const seenIds = new Set();
    for (const job of mappedJobs) {
      if (!seenIds.has(job.OfferId)) {
        seenIds.add(job.OfferId);
        uniqueJobs.push(job);
      }
    }
    const finalJobs = uniqueJobs.filter(job => {
      // If user applied, always show it (even if Closed)
      if (job.hasApplied) return true;
      // If user hasn't applied, only show it if it's Published
      return job._rawStatus === 'P';
    });

    return finalJobs;
  } catch (error) {
    console.error("Failed to fetch jobs from SAP:", error);
    return [];
  }
};

/**
 * Submit an application to SAP
 */
export const submitApplication = async (offerId, formData) => {
  try {
    // 1. Fetch CSRF Token
    const tokenResponse = await api.get("/JobOffer", {
      headers: { "x-csrf-token": "Fetch" }
    });
    const csrfToken = tokenResponse.headers['x-csrf-token'];

    // 2. Create Candidate First
    const candidatePayload = {
      FirstName: formData.firstName,
      LastName: formData.lastName,
      Email: formData.email || "test@example.com",
      Phone: formData.phone || "0000000000",
      Cin: formData.cin || "N/A"
    };

    let candidateId = null;
    let candidateETag = null;
    try {
      // Check if candidate already exists
      const candSearch = await api.get(`/Candidate?$filter=Email eq '${(formData.email || "test@example.com").toLowerCase()}'`);
      if (candSearch.data.value && candSearch.data.value.length > 0) {
        candidateId = candSearch.data.value[0].CandidateId;
        candidateETag = candSearch.data.value[0]['@odata.etag'] || '*';
      } else {
        const candRes = await api.post("/Candidate", candidatePayload, {
          headers: { "x-csrf-token": csrfToken }
        });
        candidateId = candRes.data.CandidateId;
        // Extract ETag to satisfy OData V4 concurrency control
        candidateETag = candRes.headers['etag'] || candRes.data['@odata.etag'] || '*';
      }
    } catch (candErr) {
      console.error("Failed to create/fetch candidate:", candErr);
      throw new Error("Could not process Candidate in SAP");
    }

    // 3. Call the custom RAP Action to safely apply to the Job without draft-locking
    const applyPayload = {
      OfferId: offerId,
      ResumeUrl: formData.resumeUrl || "https://example.com/resume",
      CoverLetter: formData.coverLetter || "I am very interested in this role.",
      NoticePeriod: formData.noticePeriod ? formData.noticePeriod.toString() : "30",
      SalaryExpectation: formData.salaryExpectation ? parseInt(formData.salaryExpectation) : 0,
      CurrencyCode: "USD"
    };
    
    // OData v4 Bound Action URL structure: /EntitySet(Key)/Namespace.ActionName
    const actionUrl = `/Candidate(${candidateId})/com.sap.gateway.srvd.zui_hcm_recruit.v0001.applyToJob`;
    
    const response = await api.post(actionUrl, applyPayload, {
      headers: {
        "x-csrf-token": csrfToken,
        "If-Match": candidateETag
      }
    });
    
    // Check if we got redirected to the HTML login page (session expired)
    if (typeof response.data === 'string' && response.data.includes('<html')) {
      throw new Error("Session expired. Please update your SAP Cookie.");
    }

    // 4. AI evaluation in the background: the candidate does not wait for it
    startAiEvaluation(offerId, candidateId, applyPayload.ResumeUrl);

    return response.data;
  } catch (error) {
    console.error("Failed to submit application to SAP:", error);
    throw error;
  }
};

/**
 * AI evaluation of a new application (runs in the background after submitApplication).
 * 1. Reads the job offer, 2. sends the resume link and the offer to the AI service,
 * 3. writes the score back to SAP with the RAP action setAIEvaluation.
 * The SAP calls go through the same /sap-api proxy as the rest of the portal.
 */
const AI_API_URL = import.meta.env.VITE_AI_API_URL || 'http://localhost:8000';

export const startAiEvaluation = (offerId, candidateId, resumeUrl) => {
  evaluateApplication(offerId, candidateId, resumeUrl).catch(error => {
    console.warn("AI evaluation could not be stored in SAP:", error);
  });
};

const evaluateApplication = async (offerId, candidateId, resumeUrl) => {
  if (!resumeUrl) return;

  // 1. Job offer text for the AI rubric
  const offerRes = await api.get(`/JobOffer(OfferId=${offerId},IsActiveEntity=true)`);
  const offer = offerRes.data;
  const offerInfo = [
    offer.Title,
    offer.Description,
    offer.RequiredSkills ? `Required skills: ${offer.RequiredSkills}` : '',
    offer.ExperienceLevel ? `Experience level: ${offer.ExperienceLevel}` : ''
  ].filter(Boolean).join('\n');

  // 2. AI microservice (FastAPI)
  const aiRes = await axios.post(`${AI_API_URL}/evaluate/score`, {
    gdrive_url: resumeUrl,
    offer_info: offerInfo
  });
  const ai = aiRes.data;

  // 3. The new application of this candidate for this offer
  const appRes = await api.get(
    `/Application?$filter=OfferId eq ${offerId} and CandidateId eq ${candidateId} and IsActiveEntity eq true`
  );
  const application = appRes.data?.value?.[0];
  if (!application) return;

  // 4. Write-back with the RAP action setAIEvaluation (fresh CSRF token and ETag)
  const tokenRes = await api.get(
    `/Application(ApplicationId=${application.ApplicationId},IsActiveEntity=true)`,
    { headers: { "x-csrf-token": "Fetch" } }
  );
  const csrfToken = tokenRes.headers['x-csrf-token'];
  const etag = tokenRes.headers['etag'] || tokenRes.data['@odata.etag'] || '*';

  const summary = [
    ...(ai.key_strengths || []).map(s => `+ ${s}`),
    ...(ai.areas_for_improvement || []).map(s => `- ${s}`)
  ].join('\n').substring(0, 1000);

  await api.post(
    `/Application(ApplicationId=${application.ApplicationId},IsActiveEntity=true)/com.sap.gateway.srvd.zui_hcm_recruit.v0001.setAIEvaluation`,
    {
      Score: Math.round(Number(ai.score || 0) * 100) / 100,
      Recommendation: (ai.recommendation || '').toUpperCase().substring(0, 20),
      Summary: summary
    },
    { headers: { "x-csrf-token": csrfToken, "If-Match": etag } }
  );
};

export const withdrawApplication = async (offerId, userEmail) => {
  try {
    // 1. Fetch the specific Job Offer and its applications to find the user's ApplicationId
    const response = await api.get(`/JobOffer(OfferId=${offerId},IsActiveEntity=true)?$expand=_Applications($expand=_Candidate)`);
    const job = response.data;
    
    if (job._Applications && job._Applications.length > 0) {
      const userApp = job._Applications.find(app => app._Candidate && app._Candidate.Email && app._Candidate.Email.toLowerCase() === userEmail.toLowerCase());
      
      if (userApp && userApp.ApplicationId) {
        // 2. Fetch the Application directly to get the ETag and CSRF token for deletion
        const appRes = await api.get(`/Application(ApplicationId=${userApp.ApplicationId},IsActiveEntity=true)`, {
           headers: { "x-csrf-token": "Fetch" }
        });
        const csrfToken = appRes.headers['x-csrf-token'];
        const etag = appRes.headers['etag'] || appRes.data['@odata.etag'] || '*';
        
        // 3. Send DELETE request to RAP Backend
        try {
          await api.delete(`/Application(ApplicationId=${userApp.ApplicationId},IsActiveEntity=true)`, {
            headers: {
              "x-csrf-token": csrfToken,
              "If-Match": etag
            }
          });
          console.log(`Successfully withdrew application ${userApp.ApplicationId}`);
          return true;
        } catch (delErr) {
          if (delErr.response && delErr.response.status === 409) {
            throw new Error("This application is currently being reviewed by HR. Please try again later.");
          }
          throw delErr;
        }
      }
    }
    
    console.warn("Could not find the application to withdraw.");
    return false;
  } catch (error) {
    console.error("Failed to withdraw application:", error);
    throw error;
  }
};

export const submitOnboarding = async (applicationId, formData, user) => {
  try {
    const tokenResponse = await api.get("/Onboarding", {
      headers: { "x-csrf-token": "Fetch" }
    });
    const csrfToken = tokenResponse.headers['x-csrf-token'];

    const payload = {
      FirstName: user?.firstName || formData.firstName || "Candidate", 
      LastName: user?.lastName || formData.lastName || "Name",
      DateOfBirth: formData.dateOfBirth || null,
      PlaceOfBirth: formData.placeOfBirth || "",
      Nationality: formData.nationality || "",
      Gender: formData.gender || "Male",
      MaritalStatus: formData.maritalStatus || "Single",
      NationalId: formData.nationalId || "",
      Ssn: formData.ssn || "",
      Address: formData.address || "",
      Phone: formData.phone || "",
      PersonalEmail: formData.personalEmail || user?.primaryEmailAddress?.emailAddress || "",
      BankName: formData.bankName || "",
      BankAccount: formData.bankAccount || "",
      Iban: formData.iban || "",
      EmergencyName: formData.emergencyName || "",
      EmergencyPhone: formData.emergencyPhone || "",
      EmergencyRelation: formData.emergencyRelation || ""
    };

    // Check if an onboarding record already exists for this application
    let existingForm = null;
    try {
      const searchRes = await api.get(`/Onboarding?$filter=ApplicationId eq ${applicationId} and IsActiveEntity eq true`);
      if (searchRes.data?.value?.length > 0) {
        existingForm = searchRes.data.value[0];
      }
    } catch (e) {
      console.warn("Could not query existing onboarding record:", e);
    }

    if (existingForm) {
      const formId = existingForm.FormId;
      const activeEtag = existingForm['@odata.etag'] || '*';

      // 1. Create draft from active entity
      const editUrl = `/Onboarding(FormId=${formId},IsActiveEntity=true)/com.sap.gateway.srvd.zui_hcm_recruit.v0001.Edit`;
      const editRes = await api.post(editUrl, { PreserveChanges: true }, {
        headers: { "x-csrf-token": csrfToken, "If-Match": activeEtag }
      });
      const draftEtag = editRes.headers['etag'] || editRes.data['@odata.etag'] || '*';

      // 2. Update draft with submitted form data
      const patchRes = await api.patch(`/Onboarding(FormId=${formId},IsActiveEntity=false)`, payload, {
        headers: { "x-csrf-token": csrfToken, "If-Match": draftEtag }
      });
      const updatedDraftEtag = patchRes.headers['etag'] || patchRes.data['@odata.etag'] || '*';

      // 3. Activate the draft
      const activateUrl = `/Onboarding(FormId=${formId},IsActiveEntity=false)/com.sap.gateway.srvd.zui_hcm_recruit.v0001.Activate`;
      const activateRes = await api.post(activateUrl, {}, {
        headers: { "x-csrf-token": csrfToken, "If-Match": updatedDraftEtag }
      });
      const activatedEtag = activateRes.headers['etag'] || activateRes.data['@odata.etag'] || '*';

      // 4. Call submitForm action to mark status = 'S'
      const submitUrl = `/Onboarding(FormId=${formId},IsActiveEntity=true)/com.sap.gateway.srvd.zui_hcm_recruit.v0001.submitForm`;
      await api.post(submitUrl, {}, {
        headers: { "x-csrf-token": csrfToken, "If-Match": activatedEtag }
      });
    } else {
      // Create new draft
      const createRes = await api.post("/Onboarding", { ...payload, ApplicationId: applicationId }, {
        headers: { "x-csrf-token": csrfToken }
      });
      const formId = createRes.data.FormId;
      const etag = createRes.headers['etag'] || createRes.data['@odata.etag'] || '*';

      // Activate draft
      const activateUrl = `/Onboarding(FormId=${formId},IsActiveEntity=false)/com.sap.gateway.srvd.zui_hcm_recruit.v0001.Activate`;
      const activateRes = await api.post(activateUrl, {}, {
        headers: { "x-csrf-token": csrfToken, "If-Match": etag }
      });
      const activeEtag = activateRes.headers['etag'] || activateRes.data['@odata.etag'] || '*';

      // Submit Form
      const submitUrl = `/Onboarding(FormId=${formId},IsActiveEntity=true)/com.sap.gateway.srvd.zui_hcm_recruit.v0001.submitForm`;
      await api.post(submitUrl, {}, {
        headers: { "x-csrf-token": csrfToken, "If-Match": activeEtag }
      });
    }

    return true;
  } catch (error) {
    console.error("Failed to submit onboarding to SAP:", error);
    throw error;
  }
};

export default api;
