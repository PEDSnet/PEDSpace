import {
  AsyncPipe,
  NgIf,
  NgClass,
  NgSwitch,
  NgSwitchCase,
  NgSwitchDefault
} from '@angular/common';
import { Component, OnInit, Input } from '@angular/core';
import { RouterModule } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { Observable } from 'rxjs';
import { map, tap } from 'rxjs/operators';
import { TypeBadgeComponent as BaseComponent } from 'src/app/shared/object-collection/shared/badges/type-badge/type-badge.component';
import { BrowseDefinitionDataService } from 'src/app/core/browse/browse-definition-data.service';
import { BrowseDefinition } from 'src/app/core/shared/browse-definition.model';
import { getFirstCompletedRemoteData } from 'src/app/core/shared/operators';

@Component({
  selector: 'ds-themed-type-badge',
  styleUrls: ['./type-badge.component.scss'],
  templateUrl: './type-badge.component.html',
  standalone: true,
  imports: [NgIf, NgClass, NgSwitch, NgSwitchCase, NgSwitchDefault, TranslateModule, RouterModule, AsyncPipe],
})
export class TypeBadgeComponent extends BaseComponent implements OnInit {

  @Input() interactive = true; 
  
  browseDefinition$: Observable<BrowseDefinition>;

  constructor(private browseDefinitionDataService: BrowseDefinitionDataService) {
    super();
  }

  ngOnInit() {
    // console.log('this.typeMessage:', this.typeMessage);
    this.initBrowseDefinition();
  }

  private initBrowseDefinition() {
    const fields = ['dspace.entity.type'];
    this.browseDefinition$ = this.browseDefinitionDataService.findByFields(fields).pipe(
      getFirstCompletedRemoteData(),
      map((def) => def.payload)
    );
  }

  getQueryParams(value: string) {
    const actualValue = this.object?.firstMetadataValue('dspace.entity.type') || value;
    return { value: actualValue };
  }

  getCombinedTypeMessage(): string {
    const objectType = this.object?.firstMetadataValue('dspace.entity.type');
    if (objectType && this.typeMessage === 'collection.listelement.badge') {
      return `${objectType.toLowerCase()}.${this.typeMessage}`;
    }
    return this.typeMessage;
  }

  getTypeClass(): string {
    const objectType = this.object?.firstMetadataValue('dspace.entity.type');
    let baseClass = '';
    let specificClass = '';
    let interactiveClass = this.interactive ? '' : 'non-interactive';
  
    switch (this.typeMessage) {
      case 'community.listelement.badge':
        this.interactive = false;
        return `badge-community ${interactiveClass}`; 
      case 'collection.listelement.badge':
        if (!objectType) {
          this.interactive = false;
        }
        baseClass = 'badge-collection';
        break;
      default:
        baseClass = 'badge-item';
    }

    switch (objectType) {
      case 'ConceptSet':
        specificClass = 'badge-conceptset';
        break;
      case 'DQCheck':
        specificClass = 'badge-dqcheck';
        break;
      case 'Documentation':
        specificClass = 'badge-documentation';
        break;
      case 'Study':
        specificClass = 'badge-study';
        break;
      case 'Phenotype':
        specificClass = 'badge-phenotype';
        break;
    }
  
    return `${baseClass} ${specificClass} ${interactiveClass}`.trim();
  }

  shouldBeClickable(): boolean {
    return this.interactive && this.typeMessage !== 'community.listelement.badge';
  }
}