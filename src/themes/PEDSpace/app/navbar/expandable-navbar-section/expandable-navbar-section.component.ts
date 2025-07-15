import {
  AsyncPipe,
  NgComponentOutlet,
  NgFor,
  NgIf,
} from '@angular/common';
import {
  Component,
  OnInit,
} from '@angular/core';
import { RouterLinkActive } from '@angular/router';
import { map } from 'rxjs/operators';

import { ExpandableNavbarSectionComponent as BaseComponent } from '../../../../../app/navbar/expandable-navbar-section/expandable-navbar-section.component';
import { slide } from '../../../../../app/shared/animations/slide';
import { HoverOutsideDirective } from '../../../../../app/shared/utils/hover-outside.directive';

@Component({
  selector: 'ds-themed-expandable-navbar-section',
  templateUrl: './expandable-navbar-section.component.html',
  // templateUrl: '../../../../../app/navbar/expandable-navbar-section/expandable-navbar-section.component.html',
  styleUrls: ['./expandable-navbar-section.component.scss'],
  // styleUrls: ['../../../../../app/navbar/expandable-navbar-section/expandable-navbar-section.component.scss'],
  animations: [slide],
  standalone: true,
  imports: [
    AsyncPipe,
    HoverOutsideDirective,
    NgComponentOutlet,
    NgFor,
    NgIf,
    RouterLinkActive,
  ],
})
export class ExpandableNavbarSectionComponent extends BaseComponent implements OnInit {

  // Parameters to control which subsections are shown
  // Add the keys of subsections you want to hide to this array
  // Example: hiddenSubsections = ['browse', 'search'];
  hiddenSubsections: string[] = [];

  // Parameters to control which subsections are shown
  // If this array is not empty, only these subsections will be shown
  // Example: allowedSubsections = ['browse', 'search']; (will only show browse and search)
  // Leave empty to show all subsections except those in hiddenSubsections
  allowedSubsections: string[] = [
    'browse_global_by_title',
    'browse_global_by_datecreated',
    'browse_global_by_author',
    'browse_global_by_funder',
    'browse_global_by_subject',
    'browse_global_by_tag',
    'browse_global_by_type',
  ];

  override ngOnInit() {
    super.ngOnInit();

    // Log subsection information when component initializes
    // this.subSections$.subscribe(subSections => {
    //   console.log('=== Expandable Navbar Section Debug Info ===');
    //   console.log('Section ID:', this.section.id);
    //   console.log('Section Model:', this.section.model);
    //   console.log('Total subsections:', subSections?.length || 0);

    //   if (subSections) {
    //     subSections.forEach((subSection, index) => {
    //       console.log(`Subsection ${index}:`, {
    //         id: subSection.id,
    //         model: subSection.model,
    //         visible: subSection.visible,
    //         shouldShow: this.shouldShowSubsection(subSection.id),
    //       });
    //     });
    //   }
    //   console.log('=== End Debug Info ===');
    // });
  }

  /**
   * Determine if a subsection should be shown based on the configured parameters
   */
  shouldShowSubsection(subsectionId: string): boolean {
    // If allowedSubsections is specified and not empty, only show those
    if (this.allowedSubsections.length > 0) {
      return this.allowedSubsections.includes(subsectionId);
    }

    // Otherwise, show all except those in hiddenSubsections
    return !this.hiddenSubsections.includes(subsectionId);
  }

  /**
   * Get filtered subsections based on the configured parameters
   */
  getFilteredSubsections() {
    return this.subSections$.pipe(
      map(subSections => {
        if (!subSections) {
          return subSections;
        }

        return subSections.filter(subSection => {
          const shouldShow = this.shouldShowSubsection(subSection.id);
          // console.log(`Filtering subsection ${subSection.id}:`, shouldShow);
          return shouldShow;
        });
      }),
    );
  }
}
