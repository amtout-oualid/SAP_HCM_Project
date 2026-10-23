import React, { useState, useEffect } from 'react';
import api from '../api';
import { useUser } from '@clerk/clerk-react';

const TalentPool = () => {
  const [candidates, setCandidates] = useState([]);
  const [loading, setLoading] = useState(true);
  const { isLoaded, isSignedIn, user } = useUser();
  const [search, setSearch] = useState("");

  const isHr = user?.publicMetadata?.role === 'HR';

  useEffect(() => {
    if (isLoaded && isSignedIn && isHr) {
      fetchTalentPool();
    } else if (isLoaded && !isHr) {
      setLoading(false);
    }
  }, [isLoaded, isSignedIn, isHr]);

  const fetchTalentPool = async () => {
    try {
      const response = await api.get('/TalentPool?$orderby=AddedAt desc');
      setCandidates(response.data.value || []);
    } catch (error) {
      console.error("Error fetching talent pool:", error);
    } finally {
      setLoading(false);
    }
  };

  const filteredCandidates = candidates.filter(c => 
    (c.CandidateName || "").toLowerCase().includes(search.toLowerCase()) ||
    (c.Skills || "").toLowerCase().includes(search.toLowerCase()) ||
    (c.RejectionReason || "").toLowerCase().includes(search.toLowerCase())
  );

  if (!isLoaded || loading) return <div className="p-8 text-center text-gray-500">Loading Talent Pool...</div>;

  if (!isHr) return (
    <div className="p-8 text-center text-red-500 bg-red-50 rounded-lg border border-red-200 shadow-sm">
      <i className="fa-solid fa-lock text-3xl mb-4"></i>
      <h2 className="text-xl font-bold">Access Denied</h2>
      <p>Only HR personnel can view the Talent Pool.</p>
    </div>
  );

  return (
    <div className="flex flex-col gap-6 animate-fade-in pb-10">
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
        <div>
          <h1 className="text-3xl font-bold text-gray-800 tracking-tight">Talent Pool</h1>
          <p className="text-gray-500 mt-1">Review candidates saved for future opportunities.</p>
        </div>
        
        <div className="relative w-full md:w-96">
          <i className="fa-solid fa-search absolute left-4 top-1/2 transform -translate-y-1/2 text-gray-400"></i>
          <input 
            type="text" 
            placeholder="Search by name, skills, or rejection reason..." 
            className="w-full pl-11 pr-4 py-3 bg-gray-50 border-none rounded-xl text-gray-700 focus:ring-2 focus:ring-blue-500 transition-all shadow-inner"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
      </div>

      {filteredCandidates.length === 0 ? (
        <div className="bg-white p-16 rounded-2xl shadow-sm border border-gray-100 text-center flex flex-col items-center justify-center">
          <div className="w-24 h-24 bg-gray-50 rounded-full flex items-center justify-center mb-6">
            <i className="fa-solid fa-users-slash text-4xl text-gray-300"></i>
          </div>
          <h3 className="text-xl font-bold text-gray-700 mb-2">No Candidates Found</h3>
          <p className="text-gray-500 max-w-md">There are no candidates in the talent pool matching your search criteria.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredCandidates.map(candidate => (
            <div key={candidate.PoolId} className="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden hover:shadow-md transition-shadow group flex flex-col">
              <div className="p-6 border-b border-gray-50 relative flex-1">
                <div className="absolute top-0 right-0 bg-gradient-to-l from-blue-50 to-transparent w-24 h-full opacity-0 group-hover:opacity-100 transition-opacity"></div>
                
                <div className="flex items-center gap-4 mb-4">
                  <div className="w-12 h-12 rounded-full bg-blue-100 text-blue-600 flex items-center justify-center text-xl font-bold flex-shrink-0">
                    {candidate.CandidateName ? candidate.CandidateName.charAt(0).toUpperCase() : 'C'}
                  </div>
                  <div className="min-w-0">
                    <h3 className="text-lg font-bold text-gray-800 truncate" title={candidate.CandidateName}>{candidate.CandidateName}</h3>
                    <p className="text-sm text-gray-500 truncate"><i className="fa-solid fa-envelope mr-1.5 text-gray-400"></i> {candidate.CandidateEmail}</p>
                  </div>
                </div>

                <div className="space-y-3 mb-4">
                  <div>
                    <span className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-1 block">Skills</span>
                    <p className="text-sm text-gray-700 font-medium line-clamp-2">{candidate.Skills || 'No skills listed'}</p>
                  </div>
                  <div>
                    <span className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-1 block">Rejection Reason</span>
                    <p className="text-sm text-gray-600 line-clamp-2 italic border-l-2 border-gray-200 pl-2 py-0.5">
                      "{candidate.RejectionReason || 'No reason provided'}"
                    </p>
                  </div>
                </div>
              </div>
              
              <div className="px-6 py-4 bg-gray-50/50 flex justify-between items-center mt-auto border-t border-gray-100">
                <div className="flex items-center gap-2 text-sm text-gray-500 font-medium">
                  <i className="fa-solid fa-robot text-purple-500"></i>
                  AI Match: <span className="text-gray-800 font-bold">{candidate.AiScore || 0}%</span>
                </div>
                {candidate.ResumeUrl ? (
                  <a 
                    href={candidate.ResumeUrl} 
                    target="_blank" 
                    rel="noreferrer"
                    className="text-sm font-semibold text-blue-600 hover:text-blue-700 bg-blue-50 px-3 py-1.5 rounded-lg transition-colors flex items-center gap-1.5"
                  >
                    <i className="fa-solid fa-file-pdf"></i> Resume
                  </a>
                ) : (
                  <span className="text-sm text-gray-400">No Resume</span>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default TalentPool;
