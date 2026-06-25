import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NgbAccordionModule } from '@ng-bootstrap/ng-bootstrap';
import { TranslateModule } from '@ngx-translate/core';

@Component({
  selector: 'ds-about-content',
  templateUrl: './about-content.component.html',
  styleUrls: ['./about-content.component.scss'],
  standalone: true,
  imports: [CommonModule, NgbAccordionModule, TranslateModule],
})
/**
 * Component displaying the content of the About page
 */
export class AboutContentComponent {
}
