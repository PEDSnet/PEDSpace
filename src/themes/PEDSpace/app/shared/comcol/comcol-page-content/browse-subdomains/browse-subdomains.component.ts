import { NgFor } from '@angular/common';
import {
  Component,
  ElementRef,
  HostListener,
} from '@angular/core';

interface Subdomain {
  label: string;
  href: string;
}

/**
 * A self-contained "Browse Subdomains" dropdown menu.
 *
 * This exists as a real component (rather than HTML injected into a
 * collection's intro text) because Angular's HTML sanitizer strips
 * <details>/<input>/<script>, making a genuine click-to-toggle dropdown
 * impossible to author from field content.
 *
 * Rendered by {@link ComcolPageContentComponent} when the intro text
 * contains the {@link BROWSE_SUBDOMAINS_MARKER} token.
 */
@Component({
  selector: 'ds-pedspace-browse-subdomains',
  templateUrl: './browse-subdomains.component.html',
  styleUrls: ['./browse-subdomains.component.scss'],
  standalone: true,
  imports: [NgFor],
})
export class BrowseSubdomainsComponent {

  /**
   * Whether the dropdown menu is currently open.
   */
  isOpen = false;

  /**
   * The subdomain collections to link to.
   */
  readonly subdomains: Subdomain[] = [
    { label: 'Devices', href: 'https://pedsdspace01.research.chop.edu/metadata/collections/b8fcddb4-228e-4409-aa44-3b04341e92b6' },
    { label: 'Diagnoses', href: 'https://pedsdspace01.research.chop.edu/metadata/collections/c1ce3502-0745-43c2-a8ff-2c259bb6077d' },
    { label: 'Environmental and Socionomic Factors', href: '/handle/20.500.14642/XXXX' },
    { label: 'Lab Results', href: 'https://pedsdspace01.research.chop.edu/metadata/collections/118a1a8e-c914-4e29-8669-b7a82cc0a8b8' },
    { label: 'Medications', href: 'https://pedsdspace01.research.chop.edu/metadata/collections/cc407980-d7f5-4cb2-a94a-aca8c70ebf57' },
    { label: 'Procedures', href: 'https://pedsdspace01.research.chop.edu/metadata/collections/fefb676f-fe83-40dc-b919-bc73e03a70ac' },
    { label: 'Physiological Measurements', href: 'https://pedsdspace01.research.chop.edu/metadata/collections/236af2cb-def7-40f3-9b61-afd552234160' },
    { label: 'Visits', href: 'https://pedsdspace01.research.chop.edu/metadata/collections/7793c748-ceec-46c5-a067-0a976e2fd07f' },
  ];

  constructor(private elementRef: ElementRef) {
  }

  toggle(): void {
    this.isOpen = !this.isOpen;
  }

  close(): void {
    this.isOpen = false;
  }

  /**
   * Close the menu when clicking anywhere outside of this component.
   */
  @HostListener('document:click', ['$event'])
  onDocumentClick(event: MouseEvent): void {
    if (this.isOpen && !this.elementRef.nativeElement.contains(event.target)) {
      this.close();
    }
  }

  /**
   * Close the menu when pressing Escape.
   */
  @HostListener('document:keydown.escape')
  onEscape(): void {
    this.close();
  }
}
