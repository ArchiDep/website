export class HttpAuthenticationError extends Error {
  readonly response: Response;

  constructor(response: Response) {
    super(`HTTP authentication failed with response status ${response.status}`);
    Object.setPrototypeOf(this, new.target.prototype);
    this.response = response;
  }
}
