import React from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import Navbar from './components/Navbar';
import JobBoard from './pages/JobBoard';
import JobDetails from './pages/JobDetails';
import OnboardingForm from './pages/OnboardingForm';
import TalentPool from './pages/TalentPool';
import ComingSoon from './pages/ComingSoon';

function App() {
  return (
    <BrowserRouter>
      <div className="bg-animated text-gray-800 antialiased h-screen overflow-hidden flex flex-col">
        <Navbar />
        <div className="flex-1 overflow-y-auto custom-scrollbar">
          <main className="flex flex-col px-6 py-6 max-w-[1400px] mx-auto w-full gap-6 min-h-full">
            <Routes>
            <Route path="/" element={<JobBoard />} />
            <Route path="/jobs/:id" element={<JobDetails />} />
            <Route path="/onboarding/:id" element={<OnboardingForm />} />
            <Route path="/applications" element={<JobBoard />} />
            <Route path="/talent-pool" element={<TalentPool />} />
            <Route path="*" element={<ComingSoon />} />
            </Routes>
          </main>
        </div>
      </div>
    </BrowserRouter>
  );
}

export default App;
