import { Location } from '@angular/common';
import { NO_ERRORS_SCHEMA } from '@angular/core';
import {
  ComponentFixture,
  TestBed,
  waitForAsync,
} from '@angular/core/testing';
import { NoopAnimationsModule } from '@angular/platform-browser/animations';
import {
  ActivatedRoute,
  Router,
} from '@angular/router';
import { NgbModule } from '@ng-bootstrap/ng-bootstrap';
import { TranslateModule } from '@ngx-translate/core';
import { of as observableOf } from 'rxjs';

import { Item } from '../../../../core/shared/item.model';
import { RouterMock } from '../../../../shared/mocks/router.mock';
import { VarDirective } from '../../../../shared/utils/var.directive';
import { RelatedEntitiesSearchComponent } from '../related-entities-search/related-entities-search.component';
import { TabbedRelatedEntitiesSearchComponent } from './tabbed-related-entities-search.component';

describe('TabbedRelatedEntitiesSearchComponent', () => {
  let comp: TabbedRelatedEntitiesSearchComponent;
  let fixture: ComponentFixture<TabbedRelatedEntitiesSearchComponent>;

  const mockItem = Object.assign(new Item(), {
    id: 'id1',
  });
  const mockRelationType = 'publications';
  const relationTypes = [
    {
      label: mockRelationType,
      filter: mockRelationType,
    },
  ];

  const router = new RouterMock();
  const location = jasmine.createSpyObj('location', ['replaceState']);

  beforeEach(waitForAsync(() => {
    TestBed.configureTestingModule({
      imports: [TranslateModule.forRoot(), NoopAnimationsModule, NgbModule, TabbedRelatedEntitiesSearchComponent, VarDirective],
      providers: [
        {
          provide: ActivatedRoute,
          useValue: {
            queryParams: observableOf({ tab: mockRelationType }),
          },
        },
        { provide: Router, useValue: router },
        { provide: Location, useValue: location },
      ],
      schemas: [NO_ERRORS_SCHEMA],
    })
      .overrideComponent(TabbedRelatedEntitiesSearchComponent, {
        remove: {
          imports: [
            RelatedEntitiesSearchComponent,
          ],
        },
      })
      .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(TabbedRelatedEntitiesSearchComponent);
    comp = fixture.componentInstance;
    comp.item = mockItem;
    comp.relationTypes = relationTypes;
    fixture.detectChanges();
  });

  it('should initialize the activeTab depending on the current query parameters', () => {
    comp.activeTab$.subscribe((activeTab) => {
      expect(activeTab).toEqual(mockRelationType);
    });
  });

  describe('onTabChange', () => {
    const event = {
      currentId: mockRelationType,
      nextId: 'nextTab',
    };

    beforeEach(() => {
      spyOn(router, 'createUrlTree').and.callThrough();
      spyOn(router, 'serializeUrl').and.callThrough();
      comp.onTabChange(event);
    });

    it('should update the URL with the correct tab query parameter without navigating', () => {
      expect(router.createUrlTree).toHaveBeenCalledWith([], {
        relativeTo: (comp as any).route,
        queryParams: {
          tab: event.nextId,
        },
        queryParamsHandling: 'merge',
      });
      expect(router.serializeUrl).toHaveBeenCalled();
      expect(location.replaceState).toHaveBeenCalledWith('/testing-url');
      expect(router.navigate).not.toHaveBeenCalled();
    });
  });

});
