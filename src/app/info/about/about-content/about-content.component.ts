import { CommonModule } from '@angular/common';
import { Component } from '@angular/core';
import { NgbAccordionModule } from '@ng-bootstrap/ng-bootstrap';
import { TranslateModule } from '@ngx-translate/core';

@Component({
  selector: 'ds-about-content',
  templateUrl: './about-content.component.html',
  styleUrls: ['./about-content.component.scss'],
  standalone: true,
  imports: [CommonModule, TranslateModule, NgbAccordionModule],
})
/**
 * Component displaying the content of the About page
 */
export class AboutContentComponent {
}
