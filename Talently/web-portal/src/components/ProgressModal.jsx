import React from 'react';
import ReactDOM from 'react-dom';

const ProgressModal = ({ job, onClose }) => {
  if (!job) return null;

  const steps = job.Steps || [];
  
  if (steps.length === 0) {
    return ReactDOM.createPortal(
      <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/40 backdrop-blur-sm p-4 sm:p-0 transition-opacity">
        <div className="bg-white/95 backdrop-blur-md rounded-2xl shadow-2xl w-full max-w-sm p-8 text-center animate-fade-in-up border border-gray-100" role="dialog">
          <div className="w-16 h-16 bg-gray-100 text-gray-400 rounded-full flex items-center justify-center mx-auto mb-4 text-2xl">
            <i className="fa-solid fa-timeline"></i>
          </div>
          <h2 className="text-lg font-bold text-gray-900 mb-2">Pipeline Not Available</h2>
          <p className="text-sm text-gray-500 leading-relaxed mb-6">
            There are no specific pipeline steps defined for this job offer yet. Please check back later.
          </p>
          <button 
            onClick={onClose} 
            className="w-full px-6 py-2.5 text-sm font-medium text-gray-700 bg-white border border-gray-200 hover:bg-gray-50 hover:text-gray-900 rounded-lg transition-all shadow-sm"
          >
            Close
          </button>
        </div>
      </div>,
      document.body
    );
  }

  const currentIndex = Math.min(Math.max((job.CurrentStepOrder || 1) - 1, 0), steps.length - 1);
  const currentStepStr = steps[currentIndex]?.name || job.Progress || 'Screening';

  return ReactDOM.createPortal(
    <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/40 backdrop-blur-sm p-4 sm:p-0 transition-opacity">
      <div 
        className="bg-white/95 backdrop-blur-md rounded-2xl shadow-2xl w-full max-w-lg overflow-hidden flex flex-col animate-fade-in-up border border-gray-100" 
        role="dialog"
      >
        {/* Header */}
        <div className="flex justify-between items-start p-6 border-b border-gray-100 bg-gray-50/50">
          <div>
            <h2 className="text-xl font-bold text-gray-900 leading-tight">Application Progress</h2>
            <p className="text-sm text-gray-500 mt-1">{job.Title} at {job.Company}</p>
          </div>
          <button 
            onClick={onClose} 
            className="text-gray-400 hover:text-red-500 bg-white shadow-sm hover:shadow border border-gray-200 transition-all rounded-full w-8 h-8 flex items-center justify-center focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <i className="fa-solid fa-xmark"></i>
          </button>
        </div>

        {/* Pipeline Content */}
        <div className="p-8">
          <div className="relative">
            {/* Connecting Line */}
            <div className="absolute top-1/2 left-0 w-full h-1 bg-gray-100 -translate-y-1/2 rounded-full z-0"></div>
            <div 
              className="absolute top-1/2 left-0 h-1 bg-blue-500 -translate-y-1/2 rounded-full z-0 transition-all duration-1000 ease-out" 
              style={{ width: `${(currentIndex / (steps.length - 1)) * 100}%` }}
            ></div>

            {/* Steps */}
            <div className="relative z-10 flex justify-between">
              {steps.map((step, index) => {
                const isCompleted = index <= currentIndex;
                const isCurrent = index === currentIndex;
                
                return (
                  <div key={step.name} className="flex flex-col items-center group">
                    <div 
                      className={`w-10 h-10 rounded-full flex items-center justify-center font-bold text-sm transition-all duration-500 ${
                        isCompleted 
                          ? 'bg-blue-600 text-white shadow-lg shadow-blue-500/30 scale-110' 
                          : 'bg-white border-2 border-gray-200 text-gray-400'
                      }`}
                    >
                      {isCompleted ? <i className="fa-solid fa-check"></i> : index + 1}
                    </div>
                    <span 
                      className={`mt-3 text-xs font-semibold transition-colors duration-300 ${
                        isCurrent ? 'text-blue-600' : (isCompleted ? 'text-gray-800' : 'text-gray-400')
                      }`}
                    >
                      {step.name}
                    </span>
                  </div>
                );
              })}
            </div>
          </div>
          
          {/* Status Message */}
          <div className="mt-10 p-5 bg-blue-50 border border-blue-100 rounded-xl flex items-start gap-4">
            <div className="w-10 h-10 rounded-full bg-blue-100 flex items-center justify-center text-blue-600 shrink-0">
              <i className="fa-solid fa-info"></i>
            </div>
            <div>
              <h4 className="text-sm font-bold text-gray-900 mb-1">Current Status: {currentStepStr}</h4>
              <p className="text-xs text-gray-600 leading-relaxed">
                {steps[currentIndex]?.description || "Your application is currently being reviewed."}
              </p>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="px-6 py-4 border-t border-gray-100 bg-gray-50/80 flex justify-end">
          <button 
            onClick={onClose} 
            className="px-6 py-2.5 text-sm font-medium text-gray-700 bg-white border border-gray-200 hover:bg-gray-50 hover:text-gray-900 rounded-lg transition-all shadow-sm hover:shadow"
          >
            Close
          </button>
        </div>
      </div>
    </div>,
    document.body
  );
};

export default ProgressModal;
