import { Component } from '@angular/core';
import { NgIf, NgClass, NgFor } from '@angular/common';
import { RouterLink } from '@angular/router';
import { NgbDropdownModule } from '@ng-bootstrap/ng-bootstrap';
import { TranslateModule } from '@ngx-translate/core';

/* Example base class; remove if not needed */
import { HeaderComponent as BaseComponent } from 'src/app/header/header.component';

interface NavItem {
  label: string;
  url?: string;
  children?: NavSubItem[];
}

interface NavSubItem {
  label: string;
  url: string;
}

@Component({
  selector: 'ds-pedsnet-header',
  standalone: true,
  templateUrl: './pedsnet-header.component.html',
  styleUrls: ['./pedsnet-header.component.scss'],
  imports: [
    RouterLink,
    NgIf,
    NgClass,
    NgFor,
    NgbDropdownModule,
    TranslateModule,
  ],
})
export class PEDSnetHeaderComponent extends BaseComponent {
  // Controls whether the mobile menu is collapsed.
  menuCollapsed: boolean = true;

  // Track which mobile dropdowns are open
  openMobileDropdowns: Record<string, boolean> = {};

  // Navigation structure
  navItems: NavItem[] = [
    {
      label: 'Our Network',
      url: 'https://pedsnet.org/our-network/',
      children: [
        { label: 'Mission and Vision', url: 'https://pedsnet.org/our-network/#mission-vision' },
        { label: 'PCORnet®', url: 'https://pedsnet.org/our-network/pcornet/' },
        { label: 'Policies', url: 'https://pedsnet.org/our-network/policies/' },
        { label: 'Administrative Matters', url: 'https://pedsnet.org/our-network/administrative-matters/' },
        { label: 'Institutions', url: 'https://pedsnet.org/our-network/institutions/' },
        { label: 'People', url: 'https://pedsnet.org/our-network/institutions/people/' },
        { label: 'Join PEDSnet', url: 'https://pedsnet.org/our-network/institutions/join-pedsnet/' },
        { label: 'Annual Reports', url: 'https://pedsnet.org/our-network/annual-reports/' },
      ]
    },
    {
      label: 'Research',
      url: 'https://pedsnet.org/research/',
      children: [
        { label: 'Active Studies', url: 'https://pedsnet.org/research/active-studies/' },
        { label: 'Past Studies', url: 'https://pedsnet.org/research/past-studies/' },
        { label: 'Publications', url: 'https://pedsnet.org/research/publications/' },
        { label: 'News & Impact', url: 'https://pedsnet.org/research/news-and-impact/' },
      ]
    },
    {
      label: 'Youth & Families',
      url: 'https://pedsnet.org/youth-families/',
      children: [
        { label: 'Get Involved', url: 'https://pedsnet.org/youth-families/get-involved/' },
        { label: 'Family & Youth Councils', url: 'https://pedsnet.org/youth-families/family-youth-councils/' },
        { label: 'FYREworks', url: 'https://pedsnet.org/youth-families/fyreworks/' },
        { label: 'FAQs', url: 'https://pedsnet.org/youth-families/faqs/' },
        { label: 'Apply for Engagement Core Services', url: 'https://pedsnet.org/youth-families/utilize-advisory-councils/' },
      ]
    },
    {
      label: 'Learning',
      url: 'https://pedsnet.org/learning/pedsnet-scholars-program/',
      children: []
    },
    {
      label: 'Database',
      url: 'https://pedsnet.org/database/',
      children: [
        { label: 'Patient Population', url: 'https://pedsnet.org/database/patient-population/' },
        { label: 'Data Domains', url: 'https://pedsnet.org/database/data-domains/' },
        { label: 'Data Quality', url: 'https://pedsnet.org/database/data-quality/' },
        { label: 'PEDSnet Common Data Model', url: 'https://pedsnet.org/database/pedsnet-common-data-model/' },
        { label: 'Security and Privacy', url: 'https://pedsnet.org/database/security-and-privacy/' },
        { label: 'Knowledge Bank', url: 'https://pedsnet.org/database/knowledge-bank/' },
        { label: 'Access to Data', url: 'https://pedsnet.org/database/access-to-data/' },
      ]
    },
    {
      label: 'Work with Us',
      url: 'https://pedsnet.org/work-with-us/',
      children: [
        { label: 'Contact', url: 'https://pedsnet.org/contact/' },
        { label: 'Research Process', url: 'https://pedsnet.org/work-with-us/research-process/' },
        { label: 'Collaboration Request', url: 'https://pedsnet.org/work-with-us/collaboration-request/' },
      ]
    },
  ];

  toggleMenu(): void {
    this.menuCollapsed = !this.menuCollapsed;
  }

  toggleDropdown(id: string): void {
    this.openMobileDropdowns[id] = !this.openMobileDropdowns[id];
  }

  isDropdownOpen(id: string): boolean {
    return !!this.openMobileDropdowns[id];
  }

  // For generating unique IDs
  getNavItemId(index: number): string {
    return `nav-item-${index}`;
  }
}