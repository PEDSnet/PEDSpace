import {
  NgClass,
  NgFor,
} from '@angular/common';
import { Component } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';

import { hasValue } from '../../empty.util';
import { StartsWithAbstractComponent } from '../starts-with-abstract.component';

/**
 * The numeric option shown in the strip, and the value the REST API expects for it
 */
const NUMERIC_OPTION = '0-9';
const NUMERIC_VALUE = '0';

/**
 * Component rendering the StartsWith options as a horizontal strip of
 * alphabet letter tabs (A-Z), plus a "0-9" and "All" option.
 */
@Component({
  selector: 'ds-starts-with-alphabet',
  templateUrl: './starts-with-alphabet.component.html',
  styleUrls: ['./starts-with-alphabet.component.scss'],
  standalone: true,
  imports: [NgFor, NgClass, TranslateModule],
})
export class StartsWithAlphabetComponent extends StartsWithAbstractComponent {

  /**
   * Default A-Z letters used when no startsWithOptions input is provided
   */
  private defaultAlphabet: string[] = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');

  /**
   * The letters/options to render as tabs
   */
  get displayOptions(): (string | number)[] {
    return hasValue(this.startsWithOptions) && this.startsWithOptions.length > 0
      ? this.startsWithOptions
      : this.defaultAlphabet;
  }

  ngOnInit(): void {
    super.ngOnInit();
    // the abstract component only tracks the param when it's present, but the strip also has to
    // fall back to "All" when it's removed (e.g. browser navigation)
    this.subs.push(
      this.route.queryParams.subscribe((params) => {
        if (!hasValue(params.startsWith)) {
          this.startsWith = undefined;
        }
      }),
    );
  }

  /**
   * Select a letter and update the startsWith route param
   */
  selectLetter(letter: string | number): void {
    this.startsWith = letter.toString();
    this.setStartsWithParam();
  }

  setStartsWithParam(resetPage = true): void {
    if (this.startsWith === NUMERIC_OPTION) {
      this.startsWith = NUMERIC_VALUE;
    }
    super.setStartsWithParam(resetPage);
  }

  /**
   * Clear the selection and go back to "All"
   */
  reset(): void {
    this.startsWith = undefined;
    this.setStartsWithParam();
  }

  /**
   * Whether a given letter tab is the currently active one
   */
  isActive(letter: string | number): boolean {
    const value = letter.toString() === NUMERIC_OPTION ? NUMERIC_VALUE : letter.toString();
    return this.startsWith === value;
  }
}