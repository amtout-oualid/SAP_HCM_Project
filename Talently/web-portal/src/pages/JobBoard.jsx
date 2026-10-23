import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import ProgressModal from '../components/ProgressModal';
import { useUser, useClerk } from '@clerk/clerk-react';

const JobBoard = () => {
  const navigate = useNavigate();
  const { user, isLoaded } = useUser();
  const { openSignIn } = useClerk();
  const userEmail = user?.primaryEmailAddress?.emailAddress;
  const [showMyOffers, setShowMyOffers] = useState(false);
  const [jobs, setJobs] = useState([]);
  const [filteredJobs, setFilteredJobs] = useState([]);
  const [withdrawingOfferId, setWithdrawingOfferId] = useState(null);
  const [toastMessage, setToastMessage] = useState(null);
  
  // Filter States
  const [searchQuery, setSearchQuery] = useState('');
  const [locationQuery, setLocationQuery] = useState('');
  const [sortBy, setSortBy] = useState('Latest');
  
  const [filters, setFilters] = useState({
    jobType: { 'Full-time': true, 'Freelance': true, 'Part-time': true, 'Contract': true, 'Internship': true },
    experience: { 'Entry Level': true, 'Mid Level': true, 'Senior Level': true, 'Lead / Manager': true },
    workType: { 'Remote': true, 'On-site': true, 'Hybrid': true },
    lastUpdated: '30 days ago'
  });

  const [salaryRange, setSalaryRange] = useState({ min: 0, max: 500000 });
  const [isSalaryOpen, setIsSalaryOpen] = useState(false);
  const [isSortOpen, setIsSortOpen] = useState(false);

  const salaryRef = useRef(null);
  const sortRef = useRef(null);

  useEffect(() => {
    if (!isLoaded) return; // Wait for Clerk to load to prevent double-fetching and flashing UI
    import('../api').then(({ fetchJobsFromSAP }) => {
      fetchJobsFromSAP(userEmail).then(data => {
        setJobs(data || []);
        setFilteredJobs(data || []);
      });
    });
  }, [userEmail, isLoaded]);
  useEffect(() => {
    applyFilters();
  }, [jobs, showMyOffers, filters, salaryRange, sortBy, searchQuery, locationQuery]);

  // Click outside listener for dropdowns
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (salaryRef.current && !salaryRef.current.contains(event.target)) setIsSalaryOpen(false);
      if (sortRef.current && !sortRef.current.contains(event.target)) setIsSortOpen(false);
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const handleFilterChange = (category, key) => {
    setFilters(prev => ({
      ...prev,
      [category]: {
        ...prev[category],
        [key]: !prev[category][key]
      }
    }));
  };

  const applyFilters = () => {
    let result = [...jobs];

    if (showMyOffers) {
      result = result.filter(j => j.hasApplied);
    }

    if (searchQuery) {
      result = result.filter(j => j.Title.toLowerCase().includes(searchQuery.toLowerCase()) || j.Company.toLowerCase().includes(searchQuery.toLowerCase()));
    }

    if (locationQuery && locationQuery.toLowerCase() !== 'anywhere') {
      result = result.filter(j => j.Location.toLowerCase().includes(locationQuery.toLowerCase()));
    }

    const activeJobTypes = Object.keys(filters.jobType).filter(k => filters.jobType[k]);
    if (activeJobTypes.length > 0) result = result.filter(j => activeJobTypes.includes(j.ContractType));

    const activeWorkTypes = Object.keys(filters.workType).filter(k => filters.workType[k]);
    if (activeWorkTypes.length > 0) result = result.filter(j => activeWorkTypes.includes(j.WorkType));

    const activeExp = Object.keys(filters.experience).filter(k => filters.experience[k]);
    if (activeExp.length > 0) result = result.filter(j => activeExp.includes(j.ExperienceLevel));

    result = result.filter(j => {
      return j.SalaryMax >= salaryRange.min && j.SalaryMin <= salaryRange.max;
    });

    if (sortBy === 'Latest') {
      result.sort((a, b) => new Date(b.Date) - new Date(a.Date));
    } else if (sortBy === 'Oldest') {
      result.sort((a, b) => new Date(a.Date) - new Date(b.Date));
    } else if (sortBy === 'Highest Salary') {
      result.sort((a, b) => b.SalaryMax - a.SalaryMax);
    }

    setFilteredJobs(result);
  };

  const clearFilters = () => {
    setSearchQuery('');
    setLocationQuery('');
    setFilters({
      jobType: { 'Full-time': true, 'Freelance': true, 'Part-time': true, 'Contract': true, 'Internship': true },
      experience: { 'Entry Level': true, 'Mid Level': true, 'Senior Level': true, 'Lead / Manager': true },
      workType: { 'Remote': true, 'On-site': true, 'Hybrid': true },
      lastUpdated: '30 days ago'
    });
    setSalaryRange({ min: 0, max: 500000 });
  };

  const [selectedJobForProgress, setSelectedJobForProgress] = useState(null);

  const handleApplyClick = async (e, job) => {
    e.stopPropagation();
    if (job.hasApplied) {
      setWithdrawingOfferId(job.OfferId);
      try {
        const { withdrawApplication } = await import('../api');
        const success = await withdrawApplication(job.OfferId, userEmail);
        if (success) {
          setJobs(jobs.map(j => j.OfferId === job.OfferId ? { ...j, hasApplied: false } : j));
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
    } else {
      if (!user) {
        openSignIn();
        return;
      }
      navigate(`/jobs/${job.OfferId}`);
    }
  };

  const handleProgressClick = (e, job) => {
    e.stopPropagation();
    setSelectedJobForProgress(job);
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

  return (
    <>
      {toastMessage && (
        <div className="fixed top-4 left-1/2 -translate-x-1/2 z-[200] bg-gray-900 text-white px-6 py-3 rounded-full shadow-2xl flex items-center gap-3 animate-fade-in-up font-medium text-sm">
          <i className="fa-solid fa-circle-check text-green-400 text-lg"></i>
          {toastMessage}
        </div>
      )}
      <section className="bg-white rounded-xl shadow-sm border border-gray-100 p-4 shrink-0 transition-shadow duration-300 hover:shadow-md animate-fade-in-up z-20 relative">
        <div className="flex flex-col lg:flex-row gap-4 relative">
          <div className="flex-1 flex items-center border border-gray-200 rounded-lg px-3 py-2 bg-gray-50/50 focus-within:ring-2 focus-within:ring-blue-100 focus-within:border-blue-500 transition-all duration-300 group hover:bg-white shadow-sm">
            <i className="fa-solid fa-magnifying-glass text-gray-400 mr-2 transition-colors duration-300 group-focus-within:text-blue-500"></i>
            <input 
              className="w-full bg-transparent border-none focus:ring-0 text-sm font-medium text-gray-900 placeholder-gray-400 p-0 transition-colors duration-300 outline-none" 
              placeholder="Job title or keyword" 
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && applyFilters()}
            />
          </div>
          <div className="flex-1 flex items-center border border-gray-200 rounded-lg px-3 py-2 bg-gray-50/50 focus-within:ring-2 focus-within:ring-blue-100 focus-within:border-blue-500 transition-all duration-300 group hover:bg-white shadow-sm">
            <i className="fa-solid fa-location-dot text-gray-400 mr-2 transition-colors duration-300 group-focus-within:text-blue-500"></i>
            <input 
              className="w-full bg-transparent border-none focus:ring-0 text-sm font-medium text-gray-900 placeholder-gray-400 p-0 transition-colors duration-300 outline-none" 
              placeholder="Location" 
              value={locationQuery}
              onChange={(e) => setLocationQuery(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && applyFilters()}
            />
          </div>

          <div ref={salaryRef} className="relative flex-1">
            <div onClick={() => setIsSalaryOpen(!isSalaryOpen)} className="flex items-center border border-gray-200 rounded-lg px-3 py-2 bg-gray-50/50 hover:bg-white transition-all duration-300 shadow-sm group cursor-pointer h-full">
              <i className="fa-solid fa-money-bill-wave text-gray-400 mr-2 transition-colors duration-300 group-hover:text-blue-500"></i>
              <span className="text-sm font-medium text-gray-900 flex-1 whitespace-nowrap">Min: {salaryRange.min.toLocaleString()} - Max: {salaryRange.max.toLocaleString()}</span>
              <i className={`fa-solid fa-chevron-down text-[10px] text-gray-400 ml-2 transition-transform duration-300 ${isSalaryOpen ? 'rotate-180' : ''}`}></i>
            </div>
            {isSalaryOpen && (
              <div className="absolute top-full mt-2 left-0 w-64 bg-white border border-gray-200 rounded-xl shadow-lg p-4 z-50 animate-fade-in-up">
                <h4 className="text-sm font-semibold text-gray-900 mb-3">Salary Range (Monthly)</h4>
                <div className="space-y-4">
                  <div>
                    <label className="text-xs text-gray-500 mb-1 flex justify-between"><span>Min Salary</span> <span className="font-medium text-gray-900">{salaryRange.min.toLocaleString()}</span></label>
                    <input type="range" min="0" max="500000" step="1000" value={salaryRange.min} onChange={(e) => setSalaryRange({...salaryRange, min: Math.min(parseInt(e.target.value), salaryRange.max)})} className="w-full accent-blue-600" />
                  </div>
                  <div>
                    <label className="text-xs text-gray-500 mb-1 flex justify-between"><span>Max Salary</span> <span className="font-medium text-gray-900">{salaryRange.max.toLocaleString()}</span></label>
                    <input type="range" min="0" max="500000" step="1000" value={salaryRange.max} onChange={(e) => setSalaryRange({...salaryRange, max: Math.max(parseInt(e.target.value), salaryRange.min)})} className="w-full accent-blue-600" />
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
            <button onClick={applyFilters} className="bg-blue-600 hover:bg-blue-700 text-white px-6 py-2.5 rounded-lg text-sm font-medium transition-all duration-200 hover:scale-105 active:scale-95 shadow-sm hover:shadow-md">
              Search
            </button>
          </div>
        </div>
        {/* Popular Searches */}
        <div className="mt-4 flex items-center gap-3 text-sm hidden md:flex">
          <span className="text-gray-500 font-medium">Popular searches:</span>
          <div className="flex gap-2">
            <span onClick={() => { setSearchQuery('Product Designer'); setTimeout(applyFilters, 0); }} className="bg-gray-100 text-gray-600 px-3 py-1 rounded-full text-xs font-medium cursor-pointer hover:bg-gray-200 transition-colors border border-gray-200">Product Designer</span>
            <span onClick={() => { setSearchQuery('Full-Stack Developer'); setTimeout(applyFilters, 0); }} className="bg-gray-100 text-gray-600 px-3 py-1 rounded-full text-xs font-medium cursor-pointer hover:bg-gray-200 transition-colors border border-gray-200">Full-Stack Developer</span>
            <span onClick={() => { setSearchQuery('AI Engineer'); setTimeout(applyFilters, 0); }} className="bg-gray-100 text-gray-600 px-3 py-1 rounded-full text-xs font-medium cursor-pointer hover:bg-gray-200 transition-colors border border-gray-200">AI Engineer</span>
          </div>
        </div>
      </section>

      <div className="flex gap-6 flex-1 mt-6 z-10 relative">
        <aside className="w-64 shrink-0 bg-white rounded-xl shadow-sm border border-gray-100 flex flex-col h-fit animate-fade-in-up delay-100 transition-all duration-300">
          <div className="p-5 flex items-center justify-between border-b border-gray-100">
            <h2 className="font-bold text-gray-900">Filter</h2>
            <button onClick={clearFilters} className="text-sm text-red-500 hover:text-red-600 font-medium transition-colors duration-200 hover:underline">Clear filter</button>
          </div>
          
          <div className="p-5 border-b border-gray-100 group">
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-semibold text-gray-900 text-sm">Job type</h3>
              <i className="fa-solid fa-chevron-up text-gray-400 text-xs"></i>
            </div>
            <div className="grid grid-cols-2 gap-3">
              {Object.keys(filters.jobType).map(type => (
                <label key={type} className="flex items-center gap-2 cursor-pointer group/label">
                  <input type="checkbox" checked={filters.jobType[type]} onChange={() => handleFilterChange('jobType', type)} className="rounded border-gray-300 text-blue-600 focus:ring-blue-500 w-4 h-4 cursor-pointer" />
                  <span className="text-sm text-gray-700 font-medium group-hover/label:text-gray-900 transition-colors">{type}</span>
                </label>
              ))}
            </div>
          </div>

          <div className="p-5 border-b border-gray-100 group">
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-semibold text-gray-900 text-sm">Experience</h3>
              <i className="fa-solid fa-chevron-up text-gray-400 text-xs"></i>
            </div>
            <div className="grid grid-cols-2 gap-3">
              {Object.keys(filters.experience).map(type => (
                <label key={type} className="flex items-center gap-2 cursor-pointer group/label">
                  <input type="checkbox" checked={filters.experience[type]} onChange={() => handleFilterChange('experience', type)} className="rounded border-gray-300 text-blue-600 focus:ring-blue-500 w-4 h-4 cursor-pointer" />
                  <span className="text-sm text-gray-700 font-medium group-hover/label:text-gray-900 transition-colors">{type}</span>
                </label>
              ))}
            </div>
          </div>

          <div className="p-5 border-b border-gray-100 group">
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-semibold text-gray-900 text-sm">Work type</h3>
              <i className="fa-solid fa-chevron-up text-gray-400 text-xs"></i>
            </div>
            <div className="grid grid-cols-2 gap-3">
              {Object.keys(filters.workType).map(type => (
                <label key={type} className="flex items-center gap-2 cursor-pointer group/label">
                  <input type="checkbox" checked={filters.workType[type]} onChange={() => handleFilterChange('workType', type)} className="rounded border-gray-300 text-blue-600 focus:ring-blue-500 w-4 h-4 cursor-pointer" />
                  <span className="text-sm text-gray-700 font-medium group-hover/label:text-gray-900 transition-colors">{type}</span>
                </label>
              ))}
            </div>
          </div>

          <div className="p-5 bg-[#f8fafc] rounded-b-xl mt-auto border-t border-blue-100/50 transition-colors duration-300 hover:bg-blue-50/50">
            <div className="flex items-center gap-2 mb-2">
              <i className="fa-solid fa-briefcase text-blue-600 transition-transform duration-300 hover:scale-110"></i>
              <h4 className="font-bold text-gray-900 text-sm">My Offers</h4>
            </div>
            <p className="text-xs text-gray-500 leading-relaxed mb-4">Track your applications and see the progress of roles you've applied to.</p>
            <button 
              onClick={() => setShowMyOffers(!showMyOffers)}
              className="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium text-sm py-2 rounded-lg transition-all duration-200 shadow-sm hover:shadow-md hover:scale-105 active:scale-95"
            >
              {showMyOffers ? 'View all jobs' : 'View my offers'}
            </button>
          </div>
        </aside>

        <section className="flex-1 flex flex-col min-w-0 pr-2 pb-8">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {filteredJobs.map((job, index) => (
              <article key={job.OfferId} onClick={() => navigate(`/jobs/${job.OfferId}`)} className={`bg-white rounded-xl p-5 border border-gray-100 shadow-sm hover:shadow-xl transition-all duration-300 hover:-translate-y-1 flex flex-col group cursor-pointer animate-fade-in-up delay-${(index % 5 + 2) * 100}`}>
                <div className="flex justify-between items-start mb-4">
                  <div className="flex items-center gap-3">
                    <div>
                      <div className="flex items-center gap-1">
                        <span className="text-sm text-gray-500 font-medium transition-colors duration-300 group-hover:text-gray-700">{job.Company}</span>
                      </div>
                      <h3 className="font-bold text-gray-900 text-lg leading-tight group-hover:text-blue-600 transition-colors duration-300">{job.Title}</h3>
                    </div>
                  </div>
                  <button className="text-gray-400 hover:text-blue-600 transition-all duration-200 p-1 border border-gray-200 rounded-md hover:bg-blue-50 hover:border-blue-200 active:scale-90">
                    <i className="fa-regular fa-bookmark"></i>
                  </button>
                </div>
                
                <div className="flex items-center gap-3 text-xs text-gray-500 mb-4 transition-colors duration-300 group-hover:text-gray-600">
                  <span className="flex items-center gap-1.5"><i className="fa-solid fa-briefcase text-gray-400"></i> {job.ContractType}</span>
                  <span className="w-1 h-1 bg-gray-300 rounded-full transition-colors duration-300 group-hover:bg-blue-300"></span>
                  <span className="flex items-center gap-1.5 truncate"><i className="fa-solid fa-location-dot text-gray-400"></i> {job.Location}</span>
                </div>
                
                <div className="flex flex-wrap gap-2 mb-3">
                  {job.RequiredSkills?.slice(0, 3).map((skill, i) => (
                    <span key={i} className="bg-blue-50 text-blue-600 px-2.5 py-1 rounded-md text-xs font-medium transition-colors duration-300 group-hover:bg-blue-100">
                      {skill}
                    </span>
                  ))}
                  {job.RequiredSkills?.length > 3 && (
                    <span className="bg-gray-50 text-gray-500 px-2.5 py-1 rounded-md text-xs font-medium">
                      +{job.RequiredSkills.length - 3}
                    </span>
                  )}
                </div>

                <p className="text-sm text-gray-500 mb-4 line-clamp-3 flex-1 leading-relaxed transition-colors duration-300 group-hover:text-gray-600">
                  {job.Description || `Design engaging experiences for ${job.Company}'s mobile and web platforms.`}
                </p>
                
                <div className="border-t border-gray-100 pt-4 mb-4 transition-colors duration-300 group-hover:border-gray-200">
                  <div className="flex items-center justify-between mb-1.5">
                    <span className="font-bold text-gray-900">{job.CurrencyCode || 'USD'} {job.SalaryMin.toLocaleString()} - {job.SalaryMax.toLocaleString()}<span className="text-gray-400 text-xs font-normal">/mo</span></span>
                    <span className="text-xs text-gray-400">{calculateDaysAgo(job.Date)}</span>
                  </div>
                  <div className="text-xs text-gray-500">
                    {job.PositionsNeeded} open spots &bull; {job._ApplicationsCount} Applicants
                  </div>
                </div>
                
                <div className="flex gap-2 mt-auto">
                  {job.hasApplied ? (
                    job.ApplicationStatus === 'R' ? (
                      <button disabled className="w-full bg-red-50 text-red-600 font-semibold text-sm py-2 rounded-lg transition-colors border border-red-200 cursor-not-allowed">Rejected</button>
                    ) : job.ApplicationStatus === 'A' ? (
                      <>
                        <button disabled className="flex-1 bg-green-50 text-green-600 font-semibold text-sm py-2 rounded-lg transition-colors border border-green-200 cursor-not-allowed">Accepted</button>
                        <button onClick={(e) => { e.stopPropagation(); navigate(`/onboarding/${job.ApplicationId}`); }} className="flex-1 bg-blue-600 text-white font-semibold text-sm py-2 rounded-lg transition-all duration-200 border border-blue-600 hover:bg-blue-700 shadow-sm hover:shadow-md hover:scale-105 active:scale-95">Fill Form</button>
                      </>
                    ) : (
                      <>
                        <button disabled={withdrawingOfferId === job.OfferId} onClick={(e) => handleApplyClick(e, job)} className={`flex-1 font-semibold text-sm py-2 rounded-lg transition-colors border shadow-sm ${withdrawingOfferId === job.OfferId ? 'bg-gray-100 text-gray-400 border-gray-200 cursor-not-allowed' : 'bg-gray-200 text-gray-700 border-gray-300 hover:bg-gray-300'}`}>
                          Withdraw
                        </button>
                        <button onClick={(e) => handleProgressClick(e, job)} className="flex-1 bg-blue-600 text-white font-semibold text-sm py-2 rounded-lg transition-all duration-200 border border-blue-600 hover:bg-blue-700 shadow-sm hover:shadow-md hover:scale-105 active:scale-95">Progress</button>
                      </>
                    )
                  ) : (job.PositionsFilled >= (job.PositionsNeeded||1) || (job.AppDeadline && job.AppDeadline !== '0000-00-00' && new Date(job.AppDeadline) < new Date(new Date().setHours(0,0,0,0)))) ? (
                    <button disabled className="w-full bg-gray-300 text-gray-600 font-medium text-sm py-2 rounded-lg transition-all duration-200 shadow-sm mt-auto border border-gray-300 cursor-not-allowed">Closed</button>
                  ) : (
                    <button onClick={(e) => handleApplyClick(e, job)} className="w-full bg-blue-600 hover:bg-blue-700 text-white font-medium text-sm py-2 rounded-lg transition-all duration-200 shadow-sm mt-auto hover:shadow-md hover:scale-105 active:scale-95">Apply</button>
                  )}
                </div>
              </article>
            ))}
          </div>
        </section>
      </div>

      <ProgressModal 
        job={selectedJobForProgress} 
        onClose={() => setSelectedJobForProgress(null)} 
      />
    </>
  );
};

export default JobBoard;
