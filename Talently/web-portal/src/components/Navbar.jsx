import React from 'react';
import { Link } from 'react-router-dom';
import { SignedIn, SignedOut, SignInButton, UserButton } from '@clerk/clerk-react';

const Navbar = () => {
  return (
    <header className="bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between shrink-0 transition-colors duration-300">
      {/* Logo */}
      <Link to="/" className="flex items-center gap-2 group cursor-pointer">
        <div className="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center text-white font-bold text-xl transition-transform duration-300 group-hover:rotate-12 group-hover:scale-110">
          <i className="fa-solid fa-infinity"></i>
        </div>
        <span className="text-xl font-bold text-gray-900 tracking-tight transition-colors duration-300 group-hover:text-blue-600">Talently</span>
      </Link>
      
      {/* Navigation */}
      <nav className="hidden md:flex items-center gap-6 text-sm font-medium text-gray-600">
        <Link to="/coming-soon" className="nav-link hover:text-blue-600 transition-colors duration-300">Who are we</Link>
        <Link to="/coming-soon" className="nav-link hover:text-blue-600 flex items-center gap-1 transition-colors duration-300 group">What we do <i className="fa-solid fa-chevron-down text-[10px] text-gray-400 group-hover:text-blue-600 transition-colors"></i></Link>
        <Link to="/coming-soon" className="nav-link hover:text-blue-600 flex items-center gap-1 transition-colors duration-300 group">Products <i className="fa-solid fa-chevron-down text-[10px] text-gray-400 group-hover:text-blue-600 transition-colors"></i></Link>
        <Link to="/coming-soon" className="nav-link hover:text-blue-600 flex items-center gap-1 transition-colors duration-300 group">Services <i className="fa-solid fa-chevron-down text-[10px] text-gray-400 group-hover:text-blue-600 transition-colors"></i></Link>
        <Link to="/" className="nav-link text-gray-900 flex items-center gap-1 group hover:text-blue-600">Jobs <i className="fa-solid fa-chevron-down text-[10px] text-gray-400 group-hover:text-blue-600 transition-colors"></i></Link>
        


        <Link to="/coming-soon" className="nav-link hover:text-blue-600 flex items-center gap-1 transition-colors duration-300 group">Media <i className="fa-solid fa-chevron-down text-[10px] text-gray-400 group-hover:text-blue-600 transition-colors"></i></Link>
      </nav>
      
      {/* User Actions */}
      <div className="flex items-center gap-4">
        <button className="text-gray-400 hover:text-gray-600 relative transition-transform duration-200 hover:scale-110 active:scale-95">
          <i className="fa-regular fa-bell text-lg"></i>
          <span className="absolute top-0 right-0 w-2 h-2 bg-red-500 rounded-full border border-white animate-pulse-dot"></span>
        </button>
        <div className="h-6 w-px bg-gray-200 mx-1"></div>
        <button className="flex items-center gap-2 text-sm font-medium text-gray-700 hover:bg-gray-50 px-2 py-1 rounded-md border border-gray-200 transition-all duration-200 hover:shadow-sm active:scale-95 group">
          <i className="fa-solid fa-dollar-sign text-gray-400 text-xs bg-gray-100 rounded-full w-4 h-4 flex items-center justify-center"></i>
          USD
          <i className="fa-solid fa-chevron-down text-[10px] text-gray-400 transition-transform duration-200 group-hover:rotate-180"></i>
        </button>
        
        <div className="ml-2 flex items-center justify-center">
          <SignedOut>
            <div className="hover:scale-105 transition-transform">
              <SignInButton mode="modal" className="bg-blue-600 hover:bg-blue-700 text-white font-medium text-sm py-1.5 px-4 rounded-lg transition-colors" />
            </div>
          </SignedOut>
          <SignedIn>
            <div className="hover:scale-105 transition-transform flex items-center">
              <UserButton afterSignOutUrl="/" />
            </div>
          </SignedIn>
        </div>
      </div>
    </header>
  );
};

export default Navbar;
