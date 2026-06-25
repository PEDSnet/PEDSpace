import { NgModule } from '@angular/core';
import { RouterModule } from '@angular/router';

import { environment } from '../../environments/environment';
import { i18nBreadcrumbResolver } from '../core/breadcrumbs/i18n-breadcrumb.resolver';
import { feedbackGuard } from '../core/feedback/feedback.guard';
import { ThemedAboutComponent } from './about/themed-about.component';
import { ThemedEndUserAgreementComponent } from './end-user-agreement/themed-end-user-agreement.component';
import { ThemedFeedbackComponent } from './feedback/themed-feedback.component';
import {
  ABOUT_PATH,
  END_USER_AGREEMENT_PATH,
  FEEDBACK_PATH,
  PRIVACY_PATH,
} from './info-routing-paths';
import { ThemedPrivacyComponent } from './privacy/themed-privacy.component';


const imports = [
  RouterModule.forChild([
    {
      path: FEEDBACK_PATH,
      component: ThemedFeedbackComponent,
      resolve: { breadcrumb: i18nBreadcrumbResolver },
      data: { title: 'info.feedback.title', breadcrumbKey: 'info.feedback' },
      canActivate: [feedbackGuard],
    },
  ]),
];

if (environment.info.enableEndUserAgreement) {
  imports.push(
    RouterModule.forChild([
      {
        path: END_USER_AGREEMENT_PATH,
        component: ThemedEndUserAgreementComponent,
        resolve: { breadcrumb: i18nBreadcrumbResolver },
        data: { title: 'info.end-user-agreement.title', breadcrumbKey: 'info.end-user-agreement' },
      },
    ]));
}
if (environment.info.enablePrivacyStatement) {
  imports.push(
    RouterModule.forChild([
      {
        path: PRIVACY_PATH,
        component: ThemedPrivacyComponent,
        resolve: { breadcrumb: i18nBreadcrumbResolver },
        data: { title: 'info.privacy.title', breadcrumbKey: 'info.privacy' },
      },
    ]));
}

// Add About page route
imports.push(
  RouterModule.forChild([
    {
      path: ABOUT_PATH,
      component: ThemedAboutComponent,
      resolve: { breadcrumb: i18nBreadcrumbResolver },
      data: { title: 'info.about.title', breadcrumbKey: 'info.about' },
    },
  ]),
);

@NgModule({
  imports: [
    ...imports,
  ],
})
/**
 * Module for navigating to components within the info module
 */
export class InfoRoutingModule {
}
