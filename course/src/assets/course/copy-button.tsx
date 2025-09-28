import { JSX, useEffect, useState } from 'react';
import { ClipboardDocumentIcon } from '../../shared/icons';

export type CopyButtonProps = {
  readonly textToCopy: string;
  readonly bouncy?: boolean;
};

export function CopyButton({
  textToCopy,
  bouncy
}: CopyButtonProps): JSX.Element {
  const [copied, setCopied] = useState(false);
  const [copyText, setCopyText] = useState('Copy to clipboard');

  const copyButtonTooltipOpenClass = copied ? 'tooltip-open opacity-100' : '';

  const markAsCopied = () => {
    setCopied(true);
    setCopyText('Copied!');
  };

  const iconClass =
    bouncy === true ? 'size-5 font-bold text-red-500 animate-bounce' : 'size-4';

  useEffect(() => {
    if (copied === true) {
      const id = setTimeout(() => setCopied(false), 2000);
      return () => clearTimeout(id);
    } else {
      const id = setTimeout(() => setCopyText('Copy to clipboard'), 500);
      return () => clearTimeout(id);
    }
  }, [copied]);

  return (
    <button
      type="button"
      id="student-ssh-exercise-password-copy"
      className={`cursor-pointer opacity-50 hover:opacity-100 tooltip ${copyButtonTooltipOpenClass}`}
      data-clipboard-text={textToCopy}
      onClick={markAsCopied}
    >
      <div className="tooltip-content">{copyText}</div>
      <ClipboardDocumentIcon className={iconClass} />
    </button>
  );
}
