import { NgFor } from '@angular/common';
import {
  Component,
  DestroyRef,
  ElementRef,
  HostBinding,
  HostListener,
  inject,
  OnInit,
} from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { NavigationEnd, Router, RouterLink } from '@angular/router';
import { filter } from 'rxjs/operators';

import { COMMUNITY_SUBDOMAINS, Subdomain } from './community-subdomains.map';

/**
 * A self-contained "Browse Subdomains" dropdown menu.
 *
 * Dynamically populates its link list from {@link COMMUNITY_SUBDOMAINS} by
 * matching the current community UUID extracted from the router URL.
 * Hides the host element entirely when no entry exists for the current page.
 *
 * Rendered by {@link ComcolPageContentComponent} when the intro text
 * contains the {@link BROWSE_SUBDOMAINS_MARKER} token.
 */
@Component({
  selector: 'ds-pedspace-browse-subdomains',
  templateUrl: './browse-subdomains.component.html',
  styleUrls: ['./browse-subdomains.component.scss'],
  standalone: true,
  imports: [NgFor, RouterLink],
})
export class BrowseSubdomainsComponent implements OnInit {

  isOpen = false;
  subdomains: Subdomain[] = [];

  private readonly router     = inject(Router);
  private readonly elementRef = inject(ElementRef);
  private readonly destroyRef = inject(DestroyRef);

  /**
   * Collapse the host element when there are no subdomains for this page.
   * Inline style wins over the :host { display: block } rule in SCSS, so
   * no stylesheet changes are needed.
   */
  @HostBinding('style.display')
  get hostDisplay(): string {
    return this.subdomains.length > 0 ? 'block' : 'none';
  }

  ngOnInit(): void {
    this.updateSubdomains();

    // Re-evaluate on SPA navigation in case Angular reuses this component
    // instance when moving between community pages.
    this.router.events.pipe(
      filter(e => e instanceof NavigationEnd),
      takeUntilDestroyed(this.destroyRef),
    ).subscribe(() => {
      this.updateSubdomains();
      this.close();
    });
  }

  private updateSubdomains(): void {
    const uuid = this.extractCommunityUuid();
    this.subdomains = uuid ? (COMMUNITY_SUBDOMAINS[uuid] ?? []) : [];
  }

  /**
   * Extracts the community UUID from the current router URL.
   * Handles the form /communities/{uuid}[?query].
   */
  private extractCommunityUuid(): string | null {
    const match = this.router.url.match(
      /\/communities\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/i,
    );
    return match?.[1] ?? null;
  }

  toggle(): void {
    this.isOpen = !this.isOpen;
  }

  close(): void {
    this.isOpen = false;
  }

  @HostListener('document:click', ['$event'])
  onDocumentClick(event: MouseEvent): void {
    if (this.isOpen && !this.elementRef.nativeElement.contains(event.target)) {
      this.close();
    }
  }

  @HostListener('document:keydown.escape')
  onEscape(): void {
    this.close();
  }
}