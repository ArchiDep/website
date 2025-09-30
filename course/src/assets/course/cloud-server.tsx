import { B, G, O, pipe } from '@mobily/ts-belt';
import { signal } from '@preact/signals';
import * as t from 'io-ts';
import { sample } from 'lodash-es';
import { render } from 'preact';
import { JSX, useState } from 'react';
import {
  ArrowPathIcon,
  ChevronDownIcon,
  ChevronUpIcon
} from '../../shared/icons';
import { loadingMessages } from '../../shared/loading';
import { CopyButton } from './copy-button';
import { currentSession, Student } from './session';

const cloudServerType = t.readonly(
  t.exact(
    t.type({
      name: t.union([t.string, t.null]),
      username: t.string,
      ipAddress: t.string,
      url: t.string
    })
  )
);

export const cloudServerDataType = t.readonly(
  t.exact(
    t.type({
      server: t.union([cloudServerType, t.null]),
      serversEnabled: t.boolean
    })
  )
);

export type CloudServer = t.TypeOf<typeof cloudServerType>;
export type CloudServerData = t.TypeOf<typeof cloudServerDataType>;

export const cloudServer = signal<CloudServerData | undefined>(undefined);

const cloudServerCardPrimaryProps = {
  cardClass: 'bg-primary text-primary-content',
  titleClass: '!text-primary-content'
};

const cloudServerCardSuccessProps = {
  cardClass: 'bg-success text-success-content',
  titleClass: '!text-success-content'
};

const cloudServerCardWarningProps = {
  cardClass: 'bg-warning text-warning-content',
  titleClass: '!text-warning-content'
};

type CloudServerInstructionsProps = {
  readonly mode: 'creation' | 'details';
  readonly layout?: 'horizontal' | 'vertical';
};

function CloudServerInstructions(
  props: CloudServerInstructionsProps
): JSX.Element {
  const { mode } = props;
  const layout = props.layout ?? 'vertical';

  const session = currentSession.value ?? undefined;
  const cloudServerData = cloudServer.value ?? undefined;

  if (session === undefined) {
    return (
      <CloudServerCard {...cloudServerCardWarningProps}>
        <CloudServerLoginInstructions />
      </CloudServerCard>
    );
  } else if (cloudServerData === undefined) {
    return (
      <CloudServerCard>
        <CloudServerLoadingIndicator />
      </CloudServerCard>
    );
  }

  const student = session.student ?? undefined;
  const server = cloudServerData.server ?? undefined;
  const serversEnabled = cloudServerData.serversEnabled;

  if (student === undefined) {
    return server === undefined ? (
      <CloudServerCard {...cloudServerCardWarningProps}>
        <NoRootCloudServer />
      </CloudServerCard>
    ) : (
      <CloudServerDetails mode="details" layout={layout} server={server} />
    );
  }

  if (!serversEnabled) {
    return <StudentCloudServerDisabled mode={mode} />;
  } else if (!student.usernameConfirmed) {
    return <StudentUsernameConfirmationRequired mode={mode} />;
  } else if (server === undefined) {
    return mode === 'creation' ? (
      <StudentCloudServerCreationInstructions
        layout={layout}
        username={student.username}
        domain={student.domain}
      />
    ) : (
      <StudentCloudServerCreationRequired />
    );
  }

  return (
    <CloudServerDetails
      mode={mode}
      layout={layout}
      server={server}
      student={student}
    />
  );
}

function CloudServerLoginInstructions(): JSX.Element {
  const loginUrl = `/auth/switch-edu-id/configure?to=${encodeURIComponent(window.location.pathname)}`;

  return (
    <>
      <p>
        Parts of this exercise happen on the cloud server you should have
        created for this course. Log in and make sure you are connected to the
        internet to see your server's details.
      </p>
      <div className="mt-2 card-actions justify-end">
        <a className="btn" href={loginUrl}>
          Log in
        </a>
      </div>
    </>
  );
}

function CloudServerLoadingIndicator(): JSX.Element {
  const loadingMessage = sample(loadingMessages);

  return (
    <p className="flex items-center gap-2">
      <ArrowPathIcon className="size-4 animate-spin" />
      <span>{loadingMessage}...</span>
    </p>
  );
}

function NoRootCloudServer(): JSX.Element {
  return (
    <>
      <p>
        You are root and either have not registered a server or have too many.
        Make sure only one is active to see its details here.
      </p>
      <div className="mt-2 card-actions justify-end">
        <a className="btn btn-secondary" href="/app/my-servers">
          My servers
        </a>
      </div>
    </>
  );
}

type StudentUsernameConfirmationRequiredProps = {
  readonly mode: 'creation' | 'details';
};

function StudentUsernameConfirmationRequired(
  props: StudentUsernameConfirmationRequiredProps
): JSX.Element {
  const instructions =
    props.mode === 'creation'
      ? 'You must choose a username before proceeding with this exercise.'
      : 'You must choose your username and create your cloud server before proceeding with this exercise.';

  return (
    <CloudServerCard {...cloudServerCardWarningProps}>
      <p>{instructions}</p>
      <div className="mt-2 card-actions justify-end">
        <a className="btn btn-secondary" href="/app">
          Let's do that
        </a>
      </div>
    </CloudServerCard>
  );
}

type StudentCloudServerDisabledProps = {
  readonly mode: 'creation' | 'details';
};

function StudentCloudServerDisabled({
  mode
}: StudentCloudServerDisabledProps): JSX.Element {
  const instructions =
    mode === 'creation'
      ? 'This exercise will eventually guide you through creating your own cloud server, but we have not yet reached that point in the course. Please check back later.'
      : 'You will need your own cloud server for this exercise, but we have not yet reached the point where you can create one. Please check back later.';

  return (
    <CloudServerCard>
      <p>{instructions}</p>
    </CloudServerCard>
  );
}

function StudentCloudServerCreationRequired(): JSX.Element {
  return (
    <CloudServerCard {...cloudServerCardPrimaryProps}>
      <p>
        You must create your cloud server before proceeding with this exercise.
      </p>
      <div className="mt-2 card-actions justify-end">
        <a className="btn btn-secondary" href="/app">
          Create my server
        </a>
      </div>
    </CloudServerCard>
  );
}

type StudentCloudServerCreationInstructionsProps = {
  readonly layout: 'horizontal' | 'vertical';
  readonly username: string;
  readonly domain: string;
};

function StudentCloudServerCreationInstructions({
  layout,
  username,
  domain
}: StudentCloudServerCreationInstructionsProps): JSX.Element {
  let title: string | undefined = undefined;
  if (layout === 'horizontal') {
    title = 'Cloud server setup details';
  }

  const dlClass =
    layout === 'horizontal'
      ? 'grid grid-cols-1 xs:grid-cols-2 sm:grid-cols-12 gap-1 md:gap-2 xl:gap-4'
      : '';
  const instructionsClass = layout === 'horizontal' ? 'sr-only' : '';

  return (
    <CloudServerCard title={title} {...cloudServerCardPrimaryProps}>
      <p className={instructionsClass}>
        Follow this exercise to create your cloud server. Use the following
        information.
      </p>
      <dl className={`mt-2 ${dlClass}`}>
        <div className="sm:col-span-3 flex flex-col">
          <dt className="font-bold text-xs">Username</dt>
          <dd className="flex items-center gap-2">
            <span className="font-mono">{username}</span>
            <CopyButton textToCopy={username} />
          </dd>
        </div>
        <div className="mt-1 sm:col-span-4 flex flex-col">
          <dt className="font-bold text-xs">Domain</dt>
          <dd className="flex items-center gap-2">
            <span className="font-mono">{domain}</span>
            <CopyButton textToCopy={domain} />
          </dd>
        </div>
        <div className="mt-1 hidden sm:flex sm:col-span-5 flex-col">
          <dt className="font-bold text-xs">Hostname</dt>
          <dd className="flex items-center gap-2">
            <span className="font-mono">
              {username}.{domain}
            </span>
            <CopyButton textToCopy={`${username}.${domain}`} />
          </dd>
        </div>
      </dl>
    </CloudServerCard>
  );
}

type CloudServerDetailsProps = {
  readonly mode: 'creation' | 'details';
  readonly layout: 'horizontal' | 'vertical';
  readonly server: CloudServer;
  readonly student?: Student;
};

function CloudServerDetails({
  mode,
  layout,
  server,
  student
}: CloudServerDetailsProps): JSX.Element {
  const { name, username, ipAddress } = server;
  const domain = student?.domain;

  let title: string | undefined = undefined;
  if (layout === 'horizontal') {
    title = 'Cloud server connection details';
  }

  const dlClass =
    layout === 'horizontal'
      ? 'grid grid-cols-1 xs:grid-cols-2 gap-1 md:gap-2 xl:gap-4'
      : '';

  const instructionsClass = layout === 'horizontal' ? 'sr-only' : 'mb-4';
  const instructions =
    mode === 'creation'
      ? "Congratulations! You've successfully set up your cloud server. You can now use it for the next exercises."
      : [
          'Here are the connection details for your cloud server',
          pipe(
            O.fromNullable(name),
            O.map(text => ` "${text}"`),
            O.toUndefined
          ),
          '.'
        ]
          .filter(G.isNotNullable)
          .join('');

  let cardProps = cloudServerCardSuccessProps;
  if (layout === 'horizontal') {
    cardProps = {
      ...cardProps,
      cardClass: `${cardProps.cardClass} card-xs sm:card-sm md:card-md`
    };
  }

  return (
    <CloudServerCard title={title} {...cardProps}>
      <p className={instructionsClass}>{instructions}</p>
      <dl className={`mt-2 ${dlClass}`}>
        <div className="flex flex-col">
          <dt className="font-bold text-xs">Username</dt>
          <dd className="flex items-center gap-2">
            <span className="font-mono">{username}</span>
            <CopyButton textToCopy={username} />
          </dd>
        </div>
        <div className="flex flex-col">
          <dt className="mt-1 font-bold text-xs">IP address</dt>
          <dd className="flex items-center gap-2">
            <span className="font-mono">{ipAddress}</span>
            <CopyButton textToCopy={ipAddress} />
          </dd>
        </div>
        <div className="flex flex-col">
          <dt className="mt-1 font-bold text-xs">SSH command to connect</dt>
          <dd className="flex items-center gap-2">
            <span className="font-mono">
              ssh {username}@{ipAddress}
            </span>
            <CopyButton textToCopy={`ssh ${username}@${ipAddress}`} />
          </dd>
        </div>
        {domain && (
          <div className="flex flex-col">
            <dt className="mt-1 font-bold text-xs">Hostname</dt>
            <dd className="flex items-center gap-2">
              <span className="font-mono">
                {username}.{domain}
              </span>
              <CopyButton textToCopy={`${username}.${domain}`} />
            </dd>
          </div>
        )}
      </dl>
    </CloudServerCard>
  );
}

type CloudServerCardProps = {
  readonly cardClass?: string;
  readonly title?: string | undefined;
  readonly titleClass?: string;
  readonly children: JSX.Element | JSX.Element[] | string;
};

function CloudServerCard(props: CloudServerCardProps): JSX.Element {
  const { children } = props;

  const [open, setOpen] = useState(true);
  const toggleOpen = () => setOpen(B.not);

  const cardClass = props.cardClass ?? 'bg-info text-info-content';
  const title = props.title ?? 'Cloud server exercise';
  const titleClass = props.titleClass ?? '!text-info-content';
  const detailsClass = open ? '' : 'hidden';

  return (
    <div className={`card ${cardClass} w-full`}>
      <div className="card-body">
        <div className="card-title flex justify-between items-center gap-4">
          <h2 className={titleClass}>{title}</h2>
          <button type="button" className="cursor-pointer" onClick={toggleOpen}>
            {open && <ChevronUpIcon />}
            {open || <ChevronDownIcon />}
          </button>
        </div>
        <div className={detailsClass}>{children}</div>
      </div>
    </div>
  );
}

for (const element of document.getElementsByClassName('cloud-server-data')) {
  const htmlElement = element as HTMLElement;

  const mode =
    htmlElement.dataset['mode'] === 'details' ? 'details' : 'creation';
  const layout =
    htmlElement.dataset['layout'] === 'horizontal' ? 'horizontal' : 'vertical';

  render(<CloudServerInstructions mode={mode} layout={layout} />, element);
}
