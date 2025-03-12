import { Component, ViewChildren, QueryList, ElementRef } from '@angular/core';
import { NgIf, NgClass, NgFor } from '@angular/common';
import { RouterLink } from '@angular/router';
import { NgbDropdownModule } from '@ng-bootstrap/ng-bootstrap';
import { TranslateModule } from '@ngx-translate/core';
import { trigger, state, style, animate, transition } from '@angular/animations';

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
  animations: [
    // Add animation for expanding/collapsing dropdown
    trigger('expandCollapse', [
      state('collapsed', style({
        height: '0',
        overflow: 'hidden',
        opacity: 0,
        padding: '0'
      })),
      state('expanded', style({
        height: '*',
        opacity: 1
      })),
      transition('collapsed <=> expanded', [
        animate('300ms ease-in-out')
      ])
    ])
  ]
})
export class PEDSnetHeaderComponent extends BaseComponent {

  // Track which desktop dropdowns are open
  @ViewChildren('dropdownMenu') dropdownMenus!: QueryList<ElementRef>;
  activeDropdownIndex: number | null = null;

  // Method to open dropdown on hover for desktop
  openDesktopDropdown(index: number): void {
    this.activeDropdownIndex = index;
  }

  // Method to close dropdown on mouse leave for desktop
  closeDesktopDropdown(): void {
    this.activeDropdownIndex = null;
  }

  // Method to check if a dropdown is open
  isDesktopDropdownOpen(index: number): boolean {
    return this.activeDropdownIndex === index;
  }

  openMobileDropdowns: Record<string, boolean> = {};

  // Toggle mobile dropdown
  toggleMobileDropdown(id: string): void {
    this.openMobileDropdowns[id] = !this.openMobileDropdowns[id];
  }

  // Check if mobile dropdown is open
  isMobileDropdownOpen(id: string): boolean {
    return !!this.openMobileDropdowns[id];
  }

  // Get animation state for mobile dropdown
  getMobileDropdownState(id: string): string {
    return this.isMobileDropdownOpen(id) ? 'expanded' : 'collapsed';
  }

  // Controls whether the mobile menu is collapsed.
  menuCollapsed: boolean = true;

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