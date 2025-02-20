import {
  ChangeDetectionStrategy,
  NO_ERRORS_SCHEMA,
} from '@angular/core';
import {
  ComponentFixture,
  TestBed,
  waitForAsync,
} from '@angular/core/testing';
import { By } from '@angular/platform-browser';
import {
  TranslateLoader,
  TranslateModule,
} from '@ngx-translate/core';

import { BrowseDefinitionDataService } from '../../../../../../../../app/core/browse/browse-definition-data.service';
import { BrowseDefinitionDataServiceStub } from '../../../../../../../../app/shared/testing/browse-definition-data-service.stub';
import { TranslateLoaderMock } from '../../../../../../../../app/shared/testing/translate-loader.mock';
import { APP_CONFIG } from '../../../../../../../../config/app-config.interface';
import { environment } from '../../../../../../../../environments/environment';
import { ItemPageExternalPublicationFieldComponent } from './item-page-external-publication.component';

let comp: ItemPageExternalPublicationFieldComponent;
let fixture: ComponentFixture<ItemPageExternalPublicationFieldComponent>;

describe('ItemPageExternalPublicationFieldComponent', () => {
  beforeEach(waitForAsync(() => {
    TestBed.configureTestingModule({
      imports: [
        TranslateModule.forRoot({
          loader: {
            provide: TranslateLoader,
            useClass: TranslateLoaderMock,
          },
        }),
        ItemPageExternalPublicationFieldComponent,
      ],
      providers: [
        { provide: APP_CONFIG, useValue: environment },
        { provide: BrowseDefinitionDataService, useValue: BrowseDefinitionDataServiceStub },
      ],
      schemas: [NO_ERRORS_SCHEMA],
    }).overrideComponent(ItemPageExternalPublicationFieldComponent, {
      set: { changeDetection: ChangeDetectionStrategy.Default },
    }).compileComponents();
  }));

  beforeEach(waitForAsync(() => {

    fixture = TestBed.createComponent(ItemPageExternalPublicationFieldComponent);
    comp = fixture.componentInstance;
    fixture.detectChanges();
  }));

  it('should render a ds-metadata-values', () => {
    expect(fixture.debugElement.query(By.css('ds-metadata-values'))).not.toBeNull();
  });
});
