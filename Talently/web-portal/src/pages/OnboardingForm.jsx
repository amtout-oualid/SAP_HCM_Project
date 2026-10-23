import React, { useState } from 'react';
import { useUser, RedirectToSignIn } from '@clerk/clerk-react';
import { useParams, useNavigate } from 'react-router-dom';
import { submitOnboarding } from '../api';

const OnboardingForm = () => {
  const { user, isLoaded } = useUser();
  const { id } = useParams(); // Application ID
  const navigate = useNavigate();

  const [formData, setFormData] = useState({
    dateOfBirth: '',
    placeOfBirth: '',
    nationality: '',
    maritalStatus: 'Single',
    gender: 'Male',
    nationalId: '',
    ssn: '',
    address: '',
    phone: user?.primaryPhoneNumber?.phoneNumber || '',
    personalEmail: user?.primaryEmailAddress?.emailAddress || '',
    bankName: '',
    bankAccount: '',
    iban: '',
    emergencyName: '',
    emergencyPhone: '',
    emergencyRelation: ''
  });

  const [isSubmitting, setIsSubmitting] = useState(false);

  if (!isLoaded) return <div className="p-8 text-center text-gray-500">Loading auth...</div>;
  if (!user) return <RedirectToSignIn />;

  const handleInputChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setIsSubmitting(true);
    
    try {
      await submitOnboarding(id, formData, user);
      console.log("Submitting Onboarding to SAP:", formData);
      alert('Onboarding data successfully submitted for HR Review!');
      navigate('/applications');
    } catch (error) {
      console.error(error);
      alert('Failed to submit onboarding form. Please try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="w-full max-w-4xl mx-auto space-y-6 animate-fade-in-up pb-12">
      <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-8">
        <div className="mb-8 border-b border-gray-100 pb-6">
          <div className="flex items-center gap-4 mb-2">
            <div className="w-12 h-12 bg-blue-100 text-blue-600 rounded-xl flex items-center justify-center text-xl">
              <i className="fa-solid fa-file-signature"></i>
            </div>
            <div>
              <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Onboarding Information</h1>
              <p className="text-gray-500 text-sm mt-1">Please provide the required details to finalize your employment.</p>
            </div>
          </div>
        </div>

        <form onSubmit={handleSubmit} className="space-y-8">
          
          {/* Personal Data Section */}
          <section>
            <h3 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
              <i className="fa-regular fa-id-card text-gray-400"></i> Personal Data
            </h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Date of Birth *</label>
                <input type="date" name="dateOfBirth" value={formData.dateOfBirth} onChange={handleInputChange} required className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-100 focus:border-blue-500 outline-none transition-all" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Place of Birth</label>
                <input type="text" name="placeOfBirth" value={formData.placeOfBirth} onChange={handleInputChange} className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-100 focus:border-blue-500 outline-none transition-all" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Nationality *</label>
                <input type="text" name="nationality" value={formData.nationality} onChange={handleInputChange} required className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-100 focus:border-blue-500 outline-none transition-all" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Gender</label>
                <select name="gender" value={formData.gender} onChange={handleInputChange} className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-100 focus:border-blue-500 outline-none transition-all bg-white">
                  <option value="Male">Male</option>
                  <option value="Female">Female</option>
                  <option value="Other">Other</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Marital Status</label>
                <select name="maritalStatus" value={formData.maritalStatus} onChange={handleInputChange} className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-100 focus:border-blue-500 outline-none transition-all bg-white">
                  <option value="Single">Single</option>
                  <option value="Married">Married</option>
                </select>
              </div>
            </div>
          </section>

          {/* Contact Section */}
          <section>
            <h3 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2 pt-4 border-t border-gray-100">
              <i className="fa-regular fa-address-book text-gray-400"></i> Contact & Address
            </h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="md:col-span-2">
                <label className="block text-sm font-medium text-gray-700 mb-1">Home Address *</label>
                <input type="text" name="address" value={formData.address} onChange={handleInputChange} required className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-100 focus:border-blue-500 outline-none transition-all" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Phone Number *</label>
                <input type="tel" name="phone" value={formData.phone} onChange={handleInputChange} required className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-100 focus:border-blue-500 outline-none transition-all" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Personal Email *</label>
                <input type="email" name="personalEmail" value={formData.personalEmail} onChange={handleInputChange} required className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-100 focus:border-blue-500 outline-none transition-all" />
              </div>
            </div>
          </section>

          {/* Legal & Bank Section */}
          <section>
            <h3 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2 pt-4 border-t border-gray-100">
              <i className="fa-solid fa-building-columns text-gray-400"></i> Legal & Bank Details
            </h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">National ID (CIN) *</label>
                <input type="text" name="nationalId" value={formData.nationalId} onChange={handleInputChange} required className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-100 focus:border-blue-500 outline-none transition-all" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Social Security Number</label>
                <input type="text" name="ssn" value={formData.ssn} onChange={handleInputChange} className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-100 focus:border-blue-500 outline-none transition-all" />
              </div>
              <div className="md:col-span-2 mt-2">
                <h4 className="text-sm font-semibold text-gray-900 mb-3">Bank Information</h4>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Bank Name *</label>
                <input type="text" name="bankName" value={formData.bankName} onChange={handleInputChange} required className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-100 focus:border-blue-500 outline-none transition-all" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Account Number *</label>
                <input type="text" name="bankAccount" value={formData.bankAccount} onChange={handleInputChange} required className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-100 focus:border-blue-500 outline-none transition-all" />
              </div>
              <div className="md:col-span-2">
                <label className="block text-sm font-medium text-gray-700 mb-1">IBAN *</label>
                <input type="text" name="iban" value={formData.iban} onChange={handleInputChange} required className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-100 focus:border-blue-500 outline-none transition-all font-mono" />
              </div>
            </div>
          </section>

          {/* Emergency Contact */}
          <section>
            <h3 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2 pt-4 border-t border-gray-100">
              <i className="fa-solid fa-truck-medical text-gray-400"></i> Emergency Contact
            </h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="md:col-span-2">
                <label className="block text-sm font-medium text-gray-700 mb-1">Contact Name *</label>
                <input type="text" name="emergencyName" value={formData.emergencyName} onChange={handleInputChange} required className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-100 focus:border-blue-500 outline-none transition-all" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Phone Number *</label>
                <input type="tel" name="emergencyPhone" value={formData.emergencyPhone} onChange={handleInputChange} required className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-100 focus:border-blue-500 outline-none transition-all" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Relationship *</label>
                <input type="text" name="emergencyRelation" value={formData.emergencyRelation} onChange={handleInputChange} required className="w-full px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-blue-100 focus:border-blue-500 outline-none transition-all" />
              </div>
            </div>
          </section>

          <div className="pt-8 border-t border-gray-100 flex justify-end gap-3">
            <button type="button" onClick={() => navigate('/applications')} className="px-6 py-2.5 rounded-lg font-medium text-sm text-gray-700 hover:bg-gray-100 transition-colors">
              Cancel
            </button>
            <button type="submit" disabled={isSubmitting} className={`px-8 py-2.5 rounded-lg font-medium text-sm flex items-center gap-2 text-white transition-all shadow-sm ${isSubmitting ? 'bg-blue-400 cursor-not-allowed' : 'bg-blue-600 hover:bg-blue-700 hover:shadow-md hover:scale-105 active:scale-95'}`}>
              {isSubmitting ? <><i className="fa-solid fa-spinner fa-spin"></i> Submitting...</> : <><i className="fa-solid fa-paper-plane"></i> Submit to HR</>}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default OnboardingForm;
