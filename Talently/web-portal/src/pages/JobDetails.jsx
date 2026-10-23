import React, { useState, useEffect, useRef } from 'react';
import ReactDOM from 'react-dom';
import ProgressModal from '../components/ProgressModal';
import { useParams, useNavigate } from 'react-router-dom';
import { useUser, useClerk } from '@clerk/clerk-react';

const JobDetails = () => {
  const { id } = useParams();
  const navigate = useNavigate();
  const { user, isLoaded } = useUser();
  const { openSignIn } = useClerk();
  const [job, setJob] = useState(null);
  const [showForm, setShowForm] = useState(false);
  const [applied, setApplied] = useState(false);
  const [recommendations, setRecommendations] = useState([]);
  const [selectedJobForProgress, setSelectedJobForProgress] = useState(null);

  // Form state
  const [formData, setFormData] = useState({
    firstName: user?.firstName || '',
    lastName: user?.lastName || '',
    email: user?.primaryEmailAddress?.emailAddress || '',
    phone: '',
    cin: '',
    resumeUrl: '',
    coverLetter: '',
    noticePeriod: 30,
    salaryExpectation: ''
  });

  useEffect(() => {
    if (user) {
      setFormData(prev => ({
        ...prev,
        firstName: prev.firstName || user.firstName || '',
        lastName: prev.lastName || user.lastName || '',
        email: prev.email || user.primaryEmailAddress?.emailAddress || '',
      }));
    }
  }, [user]);

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [withdrawingOfferId, setWithdrawingOfferId] = useState(null);
  const [toastMessage, setToastMessage] = useState(null);

  const [searchQuery, setSearchQuery] = useState('');
  const [locationQuery, setLocationQuery] = useState('');
  const [salaryRange, setSalaryRange] = useState({ min: 3000, max: 15000 });
  const [isSalaryOpen, setIsSalaryOpen] = useState(false);
  const [isSortOpen, setIsSortOpen] = useState(false);
  const [sortBy, setSortBy] = useState('Latest');
  
  const salaryRef = useRef(null);
  const sortRef = useRef(null);

  useEffect(() => {
    if (!isLoaded) return; // Wait for Clerk to load to prevent double-fetching and flashing UI
    import('../api').then(({ fetchJobsFromSAP }) => {
      fetchJobsFromSAP(user?.primaryEmailAddress?.emailAddress).then(data => {
        if (!data || data.length === 0) return;
        const foundJob = data.find(j => j.OfferId === id);
        if (foundJob) {
          setJob(foundJob);
          setApplied(foundJob.hasApplied);
          setRecommendations(data.filter(j => j.OfferId !== id).slice(0, 3));
        }
      });
    });
  }, [id, user?.primaryEmailAddress?.emailAddress, isLoaded]);

  useEffect(() => {
    const handleClickOutside = (event) => {
      if (salaryRef.current && !salaryRef.current.contains(event.target)) setIsSalaryOpen(false);
      if (sortRef.current && !sortRef.current.contains(event.target)) setIsSortOpen(false);
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const handleInputChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!user) {
      openSignIn();
      return;
    }
    setIsSubmitting(true);
    try {
      const { submitApplication } = await import('../api');
      const success = await submitApplication(job.OfferId, formData);
      if (success) {
        setApplied(true);
        setShowForm(false);
        setToastMessage('Application submitted successfully!');
        setTimeout(() => setToastMessage(null), 3000);
      } else {
        setToastMessage('Failed to submit application.');
        setTimeout(() => setToastMessage(null), 3000);
      }
    } catch (err) {
      console.error(err);
      setToastMessage('An error occurred.');
      setTimeout(() => setToastMessage(null), 3000);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleWithdraw = async (offerId, isMain = false) => {
    setWithdrawingOfferId(offerId);
    try {
      const { withdrawApplication } = await import('../api');
      const success = await withdrawApplication(offerId, user?.primaryEmailAddress?.emailAddress);
      if (success) {
        if (isMain) setApplied(false);
        setRecommendations(prev => prev.map(r => r.OfferId === offerId ? {...r, hasApplied: false, ApplicationStatus: 'NW'} : r));
        setToastMessage('Application successfully withdrawn!');
        setTimeout(() => setToastMessage(null), 3000);
      }
    } catch (err) {
      console.error(err);
      setToastMessage('Error withdrawing application from SAP backend.');
      setTimeout(() => setToastMessage(null), 3000);
    } finally {
      setWithdrawingOfferId(null);
    }
  };

  const calculateDaysAgo = (dateStr) => {
    if (!dateStr || dateStr === '0000-00-00' || dateStr === '00:00:00') return 'Today';
    const date = new Date(dateStr);
    if (isNaN(date.getTime())) return 'Today';
    const diffMs = new Date() - date;
    if (diffMs < 0) return 'Just now';
    const diffMins = Math.floor(diffMs / (1000 * 60));
    if (diffMins < 60) return diffMins <= 1 ? 'Just now' : `${diffMins}m ago`;
    const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
    if (diffHours < 24) return `${diffHours}h ago`;
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    return `${diffDays}d ago`;
  };

  const handleSearch = () => {
    // Navigate back to home, optionally you could pass state here if JobBoard was configured to read it
    navigate('/');
  };

  if (!job) return <div className="p-8">Loading...</div>;

  const isClosed = (job.PositionsFilled >= (job.PositionsNeeded||1)) || (job.AppDeadline && job.AppDeadline !== '0000-00-00' && new Date(job.AppDeadline) < new Date(new Date().setHours(0,0,0,0)));

  return (
    <>
      {toastMessage && ReactDOM.createPortal(
        <div className="fixed top-4 left-1/2 -translate-x-1/2 z-[200] bg-gray-900 text-white px-6 py-3 rounded-full shadow-2xl flex items-center gap-3 animate-fade-in-up font-medium text-sm">
          <i className="fa-solid fa-circle-check text-green-400 text-lg"></i>
          {toastMessage}
        </div>,
        document.body
      )}
      {/* Search Bar Area */}
      <section className="bg-white rounded-xl shadow-sm border border-gray-100 p-4 shrink-0 transition-shadow duration-300 hover:shadow-md animate-fade-in-up z-20 relative">
        <div className="flex flex-col lg:flex-row gap-4 relative">
          <div className="flex-1 flex items-center border border-gray-200 rounded-lg px-3 py-2 bg-gray-50/50 focus-within:ring-2 focus-within:ring-blue-100 focus-within:border-blue-500 transition-all cursor-text group hover:bg-white shadow-sm">
            <i className="fa-solid fa-magnifying-glass text-gray-400 mr-2 transition-colors duration-300 group-focus-within:text-blue-500"></i>
            <input 
              className="w-full bg-transparent border-none focus:ring-0 text-sm font-medium text-gray-900 placeholder-gray-400 p-0 outline-none" 
              placeholder="Job title or keyword" 
              type="text" 
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && handleSearch()}
            />
          </div>
          <div className="flex-1 flex items-center border border-gray-200 rounded-lg px-3 py-2 bg-gray-50/50 focus-within:ring-2 focus-within:ring-blue-100 focus-within:border-blue-500 transition-all cursor-text group hover:bg-white shadow-sm">
            <i className="fa-solid fa-location-dot text-gray-400 mr-2 transition-colors duration-300 group-focus-within:text-blue-500"></i>
            <input 
              className="w-full bg-transparent border-none focus:ring-0 text-sm font-medium text-gray-900 placeholder-gray-400 p-0 outline-none" 
              placeholder="Location" 
              type="text" 
              value={locationQuery}
              onChange={(e) => setLocationQuery(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && handleSearch()}
            />
          </div>

          <div ref={salaryRef} className="relative flex-1">
            <div onClick={() => setIsSalaryOpen(!isSalaryOpen)} className="flex items-center border border-gray-200 rounded-lg px-3 py-2 bg-gray-50/50 hover:bg-white transition-all duration-300 shadow-sm group cursor-pointer h-full">
              <i className="fa-solid fa-money-bill-wave text-gray-400 mr-2 transition-colors duration-300 group-hover:text-blue-500"></i>
              <span className="text-sm font-medium text-gray-900 flex-1 whitespace-nowrap">USD {salaryRange.min/1000}k - {salaryRange.max/1000}k</span>
              <i className={`fa-solid fa-chevron-down text-[10px] text-gray-400 ml-2 transition-transform duration-300 ${isSalaryOpen ? 'rotate-180' : ''}`}></i>
            </div>
            {isSalaryOpen && (
              <div className="absolute top-full mt-2 left-0 w-64 bg-white border border-gray-200 rounded-xl shadow-lg p-4 z-50 animate-fade-in-up">
                <h4 className="text-sm font-semibold text-gray-900 mb-3">Salary Range (Monthly)</h4>
                <div className="space-y-4">
                  <div>
                    <label className="text-xs text-gray-500 mb-1 flex justify-between"><span>Min Salary</span> <span className="font-medium text-gray-900">${salaryRange.min}</span></label>
                    <input type="range" min="3000" max="15000" step="500" value={salaryRange.min} onChange={(e) => setSalaryRange({...salaryRange, min: Math.min(parseInt(e.target.value), salaryRange.max)})} className="w-full accent-blue-600" />
                  </div>
                  <div>
                    <label className="text-xs text-gray-500 mb-1 flex justify-between"><span>Max Salary</span> <span className="font-medium text-gray-900">${salaryRange.max}</span></label>
                    <input type="range" min="3000" max="15000" step="500" value={salaryRange.max} onChange={(e) => setSalaryRange({...salaryRange, max: Math.max(parseInt(e.target.value), salaryRange.min)})} className="w-full accent-blue-600" />
                  </div>
                </div>
              </div>
            )}
          </div>

          <div className="flex items-center gap-3 relative">
            <div ref={sortRef} className="relative flex items-center border border-gray-200 rounded-lg px-3 py-2 bg-gray-50/50 hover:bg-white transition-all duration-300 shadow-sm group cursor-pointer h-full" onClick={() => setIsSortOpen(!isSortOpen)}>
              <i className="fa-solid fa-arrow-down-wide-short text-gray-400 transition-colors duration-300 group-hover:text-blue-500 mr-2"></i>
              <span className="text-sm text-gray-600 mr-1">Sort by:</span>
              <span className="text-sm font-medium text-gray-900">{sortBy}</span>
              <i className={`fa-solid fa-chevron-down text-[10px] text-gray-400 ml-2 transition-transform duration-300 ${isSortOpen ? 'rotate-180' : ''}`}></i>
              
              {isSortOpen && (
                <div className="absolute top-full right-0 mt-2 w-48 bg-white border border-gray-200 rounded-xl shadow-lg py-1 z-50 animate-fade-in-up">
                  {['Latest', 'Oldest', 'Highest Salary'].map(option => (
                    <div 
                      key={option} 
                      className={`px-4 py-2 text-sm cursor-pointer transition-colors ${sortBy === option ? 'bg-blue-50 text-blue-600 font-medium' : 'text-gray-700 hover:bg-gray-50'}`}
                      onClick={() => setSortBy(option)}
                    >
                      {option}
                    </div>
                  ))}
                </div>
              )}
            </div>
            <button onClick={handleSearch} className="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2.5 rounded-lg text-sm font-medium transition-all duration-200 hover:scale-105 active:scale-95 shadow-sm hover:shadow-md">
              Search
            </button>
          </div>
        </div>
        {/* Popular Searches */}
        <div className="mt-4 flex items-center gap-3 text-sm hidden md:flex">
          <span className="text-gray-500 font-medium">Popular searches:</span>
          <div className="flex gap-2">
            <span onClick={() => { setSearchQuery('Product Designer'); handleSearch(); }} className="bg-gray-100 text-gray-600 px-3 py-1 rounded-full text-xs font-medium cursor-pointer hover:bg-gray-200 transition-colors border border-gray-200">Product Designer</span>
            <span onClick={() => { setSearchQuery('Full-Stack Developer'); handleSearch(); }} className="bg-gray-100 text-gray-600 px-3 py-1 rounded-full text-xs font-medium cursor-pointer hover:bg-gray-200 transition-colors border border-gray-200">Full-Stack Developer</span>
            <span onClick={() => { setSearchQuery('AI Engineer'); handleSearch(); }} className="bg-gray-100 text-gray-600 px-3 py-1 rounded-full text-xs font-medium cursor-pointer hover:bg-gray-200 transition-colors border border-gray-200">AI Engineer</span>
          </div>
        </div>
      </section>

      <div className="flex flex-col lg:flex-row gap-6 w-full z-10 relative pb-12">
        {/* Left Column (Job Details) */}
        <div className="flex-1 animate-fade-in-up">
          {/* Top Card: Meta, Stats, Skills, Pipeline */}
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-8 mb-6">
            <button className="text-gray-500 hover:text-blue-600 mb-6 font-medium text-sm transition-colors flex items-center gap-2" onClick={() => navigate('/')}>
              <i className="fa-solid fa-arrow-left"></i> Back to Jobs
            </button>

            {/* Job Header */}
            <div className="flex justify-between items-start mb-6">
              <div className="flex space-x-4">
                <div>
                  <div className="flex items-center space-x-1 text-gray-500 text-sm mb-1">
                    <span>{job.Company}</span>
                  </div>
                  <h1 className="text-2xl font-bold text-gray-900">{job.Title}</h1>
                </div>
              </div>
              <div className="flex space-x-2">
                <button className="w-10 h-10 border border-gray-200 rounded-lg flex items-center justify-center text-gray-500 hover:bg-gray-50 transition-colors">
                  <i className="far fa-bookmark"></i>
                </button>
                <button onClick={() => { navigator.clipboard.writeText(window.location.href); alert('Link copied to clipboard!'); }} className="w-10 h-10 border border-gray-200 rounded-lg flex items-center justify-center text-gray-500 hover:bg-gray-50 transition-colors" title="Copy Link">
                  <i className="fas fa-share-nodes"></i>
                </button>
              </div>
            </div>

            {/* Job Meta */}
            <div className="flex flex-wrap items-center space-x-6 text-sm text-gray-500 mb-6">
              <div className="flex items-center space-x-2">
                <i className="fas fa-briefcase text-gray-400"></i>
                <span>{job.ContractType}</span>
              </div>
              <div className="flex items-center space-x-2">
                <i className="fas fa-map-marker-alt text-gray-400"></i>
                <span>{job.Location}</span>
              </div>
              <div className="flex items-center space-x-2 font-medium text-gray-900">
                <i className="fas fa-dollar-sign text-gray-500"></i>
                <span>{job.CurrencyCode || 'USD'} {job.SalaryMin?.toLocaleString()} - {job.SalaryMax?.toLocaleString()}<span className="text-gray-500 font-normal text-xs"> /mo</span></span>
              </div>
            </div>

            {/* Truncated Description Preview */}
            <p className="text-gray-500 text-sm mb-6 leading-relaxed">
              {job.Description ? 
                (job.Description.length > 150 ? job.Description.substring(0, 150) + '...' : job.Description) 
                : `Join ${job.Company}'s design team to craft engaging experiences across mobile and web platforms.`}
            </p>



            {/* Action Buttons */}
            <div className="flex space-x-4 mb-8">
              {applied ? (
                job.ApplicationStatus === 'R' ? (
                  <button disabled className="px-6 py-2.5 rounded-lg bg-red-50 text-red-600 font-semibold text-sm transition-all duration-200 shadow-sm border border-red-200 cursor-not-allowed">
                    Rejected
                  </button>
                ) : job.ApplicationStatus === 'A' ? (
                  <>
                    <button disabled className="px-6 py-2.5 rounded-lg bg-green-50 text-green-600 font-semibold text-sm transition-all duration-200 shadow-sm border border-green-200 cursor-not-allowed">
                      Accepted
                    </button>
                    <button 
                      className="px-6 py-2.5 rounded-lg bg-blue-600 text-white font-semibold text-sm transition-all duration-300 hover:bg-blue-700 hover:shadow-md border border-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 shadow-sm flex items-center justify-center gap-2 hover:scale-105 active:scale-95"
                      onClick={() => navigate(`/onboarding/${job.ApplicationId}`)}
                    >
                      Fill Form
                    </button>
                  </>
                ) : (
                  <>
                    <button 
                      disabled={withdrawingOfferId === job.OfferId}
                      className={`px-6 py-2.5 rounded-lg font-medium text-sm flex items-center justify-center transition-all duration-200 shadow-sm border ${withdrawingOfferId === job.OfferId ? 'bg-gray-100 text-gray-400 border-gray-200 cursor-not-allowed' : 'bg-gray-200 text-gray-700 hover:bg-gray-300 border-gray-300'}`}
                      onClick={() => handleWithdraw(job.OfferId, true)}
                    >
                      {withdrawingOfferId === job.OfferId ? 'Withdrawing...' : 'Withdraw'}
                    </button>
                    <button 
                      className="px-6 py-2.5 rounded-lg bg-blue-600 text-white font-semibold text-sm transition-all duration-300 hover:bg-blue-700 hover:shadow-md border border-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 shadow-sm flex items-center justify-center gap-2 hover:scale-105 active:scale-95"
                      onClick={() => setSelectedJobForProgress(job)}
                    >
                      Progress
                    </button>
                  </>
                )
              ) : isClosed ? (
                 <button 
                  disabled
                  className="w-full sm:w-auto bg-gray-300 text-gray-600 px-8 py-2.5 rounded-lg font-semibold text-sm cursor-not-allowed flex items-center justify-center space-x-2 border border-gray-300 shadow-sm"
                 >
                  <i className="fa-solid fa-lock"></i><span>Closed</span>
                 </button>
              ) : (
                <button 
                  className="w-full sm:w-auto bg-blue-600 text-white px-8 py-2.5 rounded-lg font-semibold text-sm transition-all duration-300 hover:bg-blue-700 hover:shadow-lg hover:-translate-y-0.5 border border-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 flex items-center justify-center space-x-2 shadow-sm"
                  onClick={() => {
                    if (!user) {
                      openSignIn();
                      return;
                    }
                    setShowForm(true);
                  }}
                >
                  <i className="fa-solid fa-bolt"></i><span>Smart Apply</span>
                </button>
              )}
            </div>

            {/* Stats Grid */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 pb-8 border-b border-gray-200 mb-8 mt-10">
              <div>
                <div className="text-[10px] font-bold text-gray-500 uppercase tracking-wider mb-2">Experience Level</div>
                <div className="font-bold text-gray-900 text-base">{job.ExperienceLevel}</div>
              </div>
              <div>
                <div className="text-[10px] font-bold text-gray-500 uppercase tracking-wider mb-2">Headcount</div>
                <div className="font-bold text-gray-900 text-base">{job.PositionsNeeded} positions</div>
                <div className="text-xs text-gray-500 mt-1">({job.PositionsFilled} filled)</div>
              </div>
              <div>
                <div className="text-[10px] font-bold text-gray-500 uppercase tracking-wider mb-2">Published On</div>
                <div className="font-bold text-gray-900 text-base">
                  {(() => {
                    const d = job.CreatedAt || job.PublishedAt || job.Date;
                    if (!d || d === '00:00:00' || d === '0000-00-00') return 'Today';
                    const date = new Date(d);
                    return isNaN(date.getTime()) ? 'Today' : date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
                  })()}
                </div>
              </div>
              <div>
                <div className="text-[10px] font-bold text-gray-500 uppercase tracking-wider mb-2">Deadline</div>
                <div className="font-bold text-gray-900 text-base">
                  {(() => {
                    const d = job.ValidUntil || job.AppDeadline;
                    if (!d || d === '00:00:00' || d === '0000-00-00') return 'Ongoing';
                    const date = new Date(d);
                    return isNaN(date.getTime()) ? 'Ongoing' : date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
                  })()}
                </div>
              </div>
            </div>

            {/* Skills and Pipeline (Now part of Top Card) */}
            {(job.RequiredSkills?.length > 0 || job.Steps?.length > 0) && (
              <>
              {job.RequiredSkills?.length > 0 && (
                <div className={job.Steps?.length > 0 ? "mb-8 pb-8 border-b border-gray-200" : ""}>
                  <h2 className="text-lg font-bold text-gray-900 mb-4">Required Skills</h2>
                  <div className="flex flex-wrap gap-2">
                    {job.RequiredSkills.map((skill, index) => (
                      <span key={index} className="px-4 py-1.5 border border-gray-200 text-gray-700 rounded-md text-xs font-semibold bg-white hover:bg-gray-50 transition-colors">
                        {skill}
                      </span>
                    ))}
                  </div>
                </div>
              )}

              {job.Steps?.length > 0 && (
                <div>
                  <h2 className="text-lg font-bold text-gray-900 mb-8">Hiring Pipeline</h2>
                  <div className="flex justify-between items-start relative max-w-2xl mx-auto px-4">
                    <div className="absolute top-5 left-10 right-10 h-0.5 bg-gray-200 -z-10"></div>
                    {job.Steps.map((step, index) => (
                      <div key={index} className="flex flex-col items-center">
                        <div className="w-10 h-10 rounded-full bg-white border-2 border-gray-300 flex items-center justify-center text-sm font-bold text-gray-500 mb-3 shadow-sm">
                          {index + 1}
                        </div>
                        <div className="text-xs font-bold text-gray-900 text-center max-w-[80px]">
                          {step.name.split(' ').map((word, i) => <div key={i}>{word}</div>)}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
              </>
            )}
          </div>

          {/* Bottom Card: About the Role */}
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-8">
            <h2 className="text-lg font-bold text-gray-900 mb-4">About the Role</h2>
            <p className="text-sm text-gray-600 leading-relaxed whitespace-pre-wrap">
              {job.Description || `As a ${job.Title} at ${job.Company}, you'll be part of a cross-functional team building delightful user experiences.`}
            </p>
          </div>


        </div>

        {/* Right Column (Sidebar Recommendations) */}
        <div className="w-full lg:w-[380px] shrink-0 flex flex-col space-y-6 animate-fade-in-up delay-100 hidden lg:block">
          <div>
            <h3 className="font-bold text-gray-900 mb-4 text-lg">Recommended for You</h3>
            <div className="space-y-4">
              {recommendations.map((rec, index) => {
                const isRecClosed = (rec.PositionsFilled >= (rec.PositionsNeeded || 1)) || (rec.AppDeadline && rec.AppDeadline !== '0000-00-00' && new Date(rec.AppDeadline) < new Date(new Date().setHours(0, 0, 0, 0)));
                return (
                  <article 
                    key={rec.OfferId} 
                    onClick={() => navigate(`/jobs/${rec.OfferId}`)} 
                    className={`bg-white rounded-xl p-5 border border-gray-100 shadow-sm hover:shadow-xl transition-all duration-300 hover:-translate-y-1 flex flex-col group cursor-pointer animate-fade-in-up delay-${(index % 5 + 2) * 100}`}
                  >
                    <div className="flex justify-between items-start mb-4">
                      <div className="flex items-center gap-3">
                        <div>
                          <div className="flex items-center gap-1">
                            <span className="text-sm text-gray-500 font-medium transition-colors duration-300 group-hover:text-gray-700">{rec.Company}</span>
                          </div>
                          <h3 className="font-bold text-gray-900 text-lg leading-tight group-hover:text-blue-600 transition-colors duration-300 line-clamp-1">{rec.Title}</h3>
                        </div>
                      </div>
                      <button 
                        className="text-gray-400 hover:text-blue-600 transition-all duration-200 p-1 border border-gray-200 rounded-md hover:bg-blue-50 hover:border-blue-200 active:scale-90" 
                        onClick={(e) => e.stopPropagation()}
                      >
                        <i className="fa-regular fa-bookmark"></i>
                      </button>
                    </div>
                    
                    <div className="flex items-center gap-3 text-xs text-gray-500 mb-4 transition-colors duration-300 group-hover:text-gray-600">
                      <span className="flex items-center gap-1.5"><i className="fa-solid fa-briefcase text-gray-400"></i> {rec.ContractType}</span>
                      <span className="w-1 h-1 bg-gray-300 rounded-full transition-colors duration-300 group-hover:bg-blue-300"></span>
                      <span className="flex items-center gap-1.5 truncate"><i className="fa-solid fa-location-dot text-gray-400"></i> {rec.Location}</span>
                    </div>
                    
                    <div className="flex flex-wrap gap-2 mb-3">
                      {rec.RequiredSkills?.slice(0, 3).map((skill, i) => (
                        <span key={i} className="bg-blue-50 text-blue-600 px-2.5 py-1 rounded-md text-xs font-medium transition-colors duration-300 group-hover:bg-blue-100">
                          {skill}
                        </span>
                      ))}
                      {rec.RequiredSkills?.length > 3 && (
                        <span className="bg-gray-50 text-gray-500 px-2.5 py-1 rounded-md text-xs font-medium">
                          +{rec.RequiredSkills.length - 3}
                        </span>
                      )}
                    </div>

                    <p className="text-sm text-gray-500 mb-4 line-clamp-3 flex-1 leading-relaxed transition-colors duration-300 group-hover:text-gray-600">
                      {rec.Description || `Design engaging experiences for ${rec.Company}'s mobile and web platforms.`}
                    </p>
                    
                    <div className="border-t border-gray-100 pt-4 mb-4 transition-colors duration-300 group-hover:border-gray-200">
                      <div className="flex items-center justify-between mb-1.5">
                        <span className="font-bold text-gray-900">
                          {rec.CurrencyCode || 'USD'} {rec.SalaryMin?.toLocaleString() || 0} - {rec.SalaryMax?.toLocaleString() || 0}
                          <span className="text-gray-400 text-xs font-normal">/mo</span>
                        </span>
                        <span className="text-xs text-gray-400">{calculateDaysAgo(rec.Date)}</span>
                      </div>
                      <div className="text-xs text-gray-500">
                        {rec.PositionsNeeded || 1} open spots &bull; {rec._ApplicationsCount || 0} Applicants
                      </div>
                    </div>
                    
                    <div className="flex gap-2 mt-auto">
                      {rec.hasApplied ? (
                        rec.ApplicationStatus === 'R' ? (
                          <button disabled className="w-full bg-red-50 text-red-600 font-semibold text-sm py-2 rounded-lg transition-colors border border-red-200 cursor-not-allowed">Rejected</button>
                        ) : rec.ApplicationStatus === 'A' ? (
                          <>
                            <button disabled className="flex-1 bg-green-50 text-green-600 font-semibold text-sm py-2 rounded-lg transition-colors border border-green-200 cursor-not-allowed">Accepted</button>
                            <button onClick={(e) => { e.stopPropagation(); navigate(`/onboarding/${rec.ApplicationId}`); }} className="flex-1 bg-blue-600 text-white font-semibold text-sm py-2 rounded-lg transition-all duration-200 border border-blue-600 hover:bg-blue-700 shadow-sm hover:shadow-md hover:scale-105 active:scale-95">Fill Form</button>
                          </>
                        ) : (
                          <>
                            <button 
                              disabled={withdrawingOfferId === rec.OfferId} 
                              onClick={(e) => { e.stopPropagation(); handleWithdraw(rec.OfferId); }} 
                              className={`flex-1 font-semibold text-sm py-2 rounded-lg transition-colors border shadow-sm ${withdrawingOfferId === rec.OfferId ? 'bg-gray-100 text-gray-400 border-gray-200 cursor-not-allowed' : 'bg-gray-200 text-gray-700 border-gray-300 hover:bg-gray-300'}`}
                            >
                              Withdraw
                            </button>
                            <button 
                              onClick={(e) => { e.stopPropagation(); setSelectedJobForProgress(rec); }} 
                              className="flex-1 bg-blue-600 text-white font-semibold text-sm py-2 rounded-lg transition-all duration-200 border border-blue-600 hover:bg-blue-700 shadow-sm hover:shadow-md hover:scale-105 active:scale-95"
                            >
                              Progress
                            </button>
                          </>
                        )
                      ) : isRecClosed ? (
                        <button disabled className="w-full bg-gray-300 text-gray-600 font-medium text-sm py-2 rounded-lg transition-all duration-200 shadow-sm mt-auto border border-gray-300 cursor-not-allowed">Closed</button>
                      ) : (
                        <button 
                          onClick={(e) => { 
                            e.stopPropagation(); 
                            if (!user) {
                              openSignIn();
                              return;
                            }
                            navigate(`/jobs/${rec.OfferId}`); 
                          }} 
                          className="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium text-sm py-2 rounded-lg transition-all duration-200 shadow-sm mt-auto hover:shadow-md hover:scale-105 active:scale-95"
                        >
                          Apply
                        </button>
                      )}
                    </div>
                  </article>
                );
              })}
            </div>
          </div>
        </div>

      </div>

      {/* Smart Apply Modal Overlay (Rendered outside the scroll container!) */}
      {showForm && !applied && ReactDOM.createPortal(
        <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/30 backdrop-blur-sm p-4 sm:p-0">
          <div aria-labelledby="modal-title" aria-modal="true" className="bg-white/95 backdrop-blur-md rounded-xl shadow-xl w-full max-w-lg max-h-[90vh] overflow-hidden flex flex-col animate-fade-in-up" role="dialog">
            <div className="flex justify-between items-start p-6 border-b border-gray-100">
              <div>
                <h2 className="text-xl font-bold text-gray-900 leading-tight" id="modal-title">Smart Apply</h2>
                <p className="text-sm text-gray-500 mt-1">{job.Title} at {job.Company}</p>
              </div>
              <button onClick={() => setShowForm(false)} className="text-gray-400 hover:text-gray-600 transition-colors rounded-md p-1 focus:outline-none focus:ring-2 focus:ring-blue-500">
                <i className="fa-solid fa-xmark text-lg"></i>
              </button>
            </div>

            <form id="apply-form" onSubmit={handleSubmit} className="p-6 overflow-y-auto flex-1">
              <div className="space-y-5 text-sm">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
                  <div>
                    <label className="block font-medium text-gray-700 mb-1">First Name</label>
                    <input className="w-full rounded-md border border-gray-200 bg-gray-50/80 px-3 py-2 text-gray-900 focus:border-blue-500 focus:bg-white focus:ring-1 focus:ring-blue-500 outline-none transition-all" name="firstName" value={formData.firstName} onChange={handleInputChange} required />
                  </div>
                  <div>
                    <label className="block font-medium text-gray-700 mb-1">Last Name</label>
                    <input className="w-full rounded-md border border-gray-200 bg-gray-50/80 px-3 py-2 text-gray-900 focus:border-blue-500 focus:bg-white focus:ring-1 focus:ring-blue-500 outline-none transition-all" name="lastName" value={formData.lastName} onChange={handleInputChange} required />
                  </div>
                </div>

                <div>
                  <label className="block font-medium text-gray-700 mb-1">Email Address</label>
                  <input className="w-full rounded-md border border-gray-200 bg-gray-50/80 px-3 py-2 text-gray-900 focus:border-blue-500 focus:bg-white focus:ring-1 focus:ring-blue-500 outline-none transition-all" type="email" name="email" value={formData.email} onChange={handleInputChange} required />
                </div>

                <div>
                  <label className="block font-medium text-gray-700 mb-1">Phone Number</label>
                  <input className="w-full rounded-md border border-gray-200 bg-gray-50/80 px-3 py-2 text-gray-900 focus:border-blue-500 focus:bg-white focus:ring-1 focus:ring-blue-500 outline-none transition-all" type="tel" name="phone" value={formData.phone} onChange={handleInputChange} required />
                </div>

                <div>
                  <label className="block font-medium text-gray-700 mb-1">Candidate ID Number (CIN)</label>
                  <input className="w-full rounded-md border border-gray-200 bg-gray-50/80 px-3 py-2 text-gray-900 focus:border-blue-500 focus:bg-white focus:ring-1 focus:ring-blue-500 outline-none transition-all" type="text" name="cin" value={formData.cin} onChange={handleInputChange} required />
                </div>

                <div>
                  <label className="block font-medium text-gray-700 mb-1">Resume Link (Google Drive URL)</label>
                  <input className="w-full rounded-md border border-gray-200 bg-gray-50/80 px-3 py-2 text-gray-900 focus:border-blue-500 focus:bg-white focus:ring-1 focus:ring-blue-500 outline-none transition-all" type="url" name="resumeUrl" value={formData.resumeUrl} onChange={handleInputChange} required />
                  <p className="mt-1.5 text-xs text-gray-500">Please ensure link sharing is set to 'Anyone with the link'.</p>
                </div>

                <div>
                  <label className="block font-medium text-gray-700 mb-1">Cover Letter</label>
                  <textarea rows="4" className="w-full rounded-md border border-gray-200 bg-gray-50/80 px-3 py-2 text-gray-900 focus:border-blue-500 focus:bg-white focus:ring-1 focus:ring-blue-500 outline-none transition-all resize-y" name="coverLetter" value={formData.coverLetter} onChange={handleInputChange} placeholder="Tell us why you are a great fit..."></textarea>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
                  <div>
                    <label className="block font-medium text-gray-700 mb-1">Notice Period (Days)</label>
                    <input className="w-full rounded-md border border-gray-200 bg-gray-50/80 px-3 py-2 text-gray-900 focus:border-blue-500 focus:bg-white focus:ring-1 focus:ring-blue-500 outline-none transition-all" type="number" min="0" name="noticePeriod" value={formData.noticePeriod} onChange={handleInputChange} required />
                  </div>
                  <div>
                    <label className="block font-medium text-gray-700 mb-1">Salary Expectation (Optional)</label>
                    <input className="w-full rounded-md border border-gray-200 bg-gray-50/80 px-3 py-2 text-gray-900 focus:border-blue-500 focus:bg-white focus:ring-1 focus:ring-blue-500 outline-none transition-all" type="number" min="0" name="salaryExpectation" value={formData.salaryExpectation} onChange={handleInputChange} placeholder="e.g. 80000" />
                  </div>
                </div>
              </div>
            </form>

            <div className="px-6 py-4 border-t border-gray-100 bg-gray-50/50 flex justify-end gap-3 rounded-b-xl">
              <button type="button" disabled={isSubmitting} onClick={() => setShowForm(false)} className="px-4 py-2 text-sm font-medium text-gray-600 bg-transparent hover:text-gray-900 hover:bg-gray-200 rounded-lg transition-colors">
                Cancel
              </button>
              <button type="submit" form="apply-form" disabled={isSubmitting} className={`inline-flex items-center gap-2 px-5 py-2 text-sm font-medium text-white rounded-lg transition-colors shadow-sm ${isSubmitting ? 'bg-blue-400 cursor-not-allowed' : 'bg-blue-600 hover:bg-blue-700'}`}>
                {isSubmitting ? <><i className="fa-solid fa-circle-notch fa-spin"></i> Submitting...</> : <><i className="fas fa-bolt"></i> Submit Application</>}
              </button>
            </div>
          </div>
        </div>,
        document.body
      )}

      <ProgressModal 
        job={selectedJobForProgress} 
        onClose={() => setSelectedJobForProgress(null)} 
      />
    </>
  );
};

export default JobDetails;
