import { createCustomApiCallAction } from '@activepieces/pieces-common';
import {
	OAuth2PropertyValue,
	PieceAuth,
	createPiece,
	Property,
} from '@activepieces/pieces-framework';
import { PieceCategory } from '@activepieces/shared';
import { sendMessageAction } from './lib/actions/send-message.action';
import crypto from 'node:crypto';
import { noteAddedToConversation } from './lib/triggers/note-added-to-conversation';
import { addNoteToConversation } from './lib/actions/add-note-to-conversation';
import { replyToConversation } from './lib/actions/reply-to-conversation';
import { newConversationFromUser } from './lib/triggers/new-conversation-from-user';
import { replyFromUser } from './lib/triggers/reply-from-user';
import { replyFromAdmin } from './lib/triggers/reply-from-admin';
import { conversationAssigned } from './lib/triggers/conversation-assigned';
import { conversationClosed } from './lib/triggers/conversation-closed';
import { conversationSnoozed } from './lib/triggers/conversation-snoozed';
import { conversationUnsnoozed } from './lib/triggers/conversation-unsnoozed';
import { conversationRated } from './lib/triggers/conversation-rated';
import { conversationPartTagged } from './lib/triggers/conversation-part-tagged';
import { findConversationAction } from './lib/actions/find-conversation';
import { addNoteToUserAction } from './lib/actions/add-note-to-user';
import { findUserAction } from './lib/actions/find-user';
import { findLeadAction } from './lib/actions/find-lead';
import { addOrRemoveTagOnConversationAction } from './lib/actions/add-remove-tag-on-conversation';
import { addOrRemoveTagOnCompanyAction } from './lib/actions/add-remove-tag-on-company';
import { createUserAction } from './lib/actions/create-user';
import { createOrUpdateUserAction } from './lib/actions/create-update-user';
import { listAllTagsAction } from './lib/actions/list-all-tags';
import { newLeadTrigger } from './lib/triggers/new-lead';
import { newCompanyTrigger } from './lib/triggers/new-company';
import { addOrRemoveTagOnContactAction } from './lib/actions/add-remove-tag-on-contact';
import { createArticleAction } from './lib/actions/create-article';
import { createConversationAction } from './lib/actions/create-conversation';
import { getConversationAction } from './lib/actions/get-conversation';
import { createOrUpdateLeadAction } from './lib/actions/create-update-lead';
import { createTicketAction } from './lib/actions/create-ticket';
import { updateTicketAction } from './lib/actions/update-ticket';
import { findCompanyAction } from './lib/actions/find-company';

export const intercomAuth = PieceAuth.OAuth2({
	authUrl: 'https://app.{region}.com/oauth',
	tokenUrl: 'https://api.{region}.io/auth/eagle/token',
	required: true,
	scope: [],
	props: {
		region: Property.StaticDropdown({
			displayName: 'Region',
			required: true,
			options: {
				options: [
					{ label: 'US', value: 'intercom' },
					{ label: 'EU', value: 'eu.intercom' },
					{ label: 'AU', value: 'au.intercom' },
				],
			},
		}),
	},
});

export const intercom = createPiece({
	displayName: 'Intercom',
	description: 'Customer messaging platform for sales, marketing, and support',
	minimumSupportedRelease: '0.29.0', // introduction of new intercom APP_WEBHOOK
	logoUrl: 'https://cdn.activepieces.com/pieces/intercom.png',
	categories: [PieceCategory.CUSTOMER_SUPPORT],
	auth: intercomAuth,
	triggers: [
		newConversationFromUser,
		replyFromUser,
		replyFromAdmin,
		noteAddedToConversation,
		conversationAssigned,
		conversationClosed,
		conversationSnoozed,
		conversationUnsnoozed,
		conversationRated,
		conversationPartTagged,
		newLeadTrigger,
		newCompanyTrigger
	],
	authors: [
		'kishanprmr',
		'MoShizzle',
		'AbdulTheActivePiecer',
		'khaledmashaly',
		'abuaboud',
		'AdamSelene',
	],
	actions: [
		addNoteToUserAction,
		addNoteToConversation,
		addOrRemoveTagOnContactAction,
		addOrRemoveTagOnCompanyAction,
		addOrRemoveTagOnConversationAction,
		createArticleAction,
		createConversationAction,
		createTicketAction,
		createUserAction,
		createOrUpdateLeadAction,
		createOrUpdateUserAction,
		replyToConversation,
		sendMessageAction,
		updateTicketAction,
		findCompanyAction,
		findConversationAction,
		findLeadAction,
		findUserAction,
		listAllTagsAction,
		getConversationAction,
		createCustomApiCallAction({
			baseUrl: (auth) => `https://api.${(auth as OAuth2PropertyValue).props?.['region']}.io`,
			auth: intercomAuth,
			authMapping: async (auth) => ({
				Authorization: `Bearer ${(auth as OAuth2PropertyValue).access_token}`,
			}),
		}),
	],
	events: {
    parseAndReply: ({ payload }) => {
      const payloadBody = payload.body as PayloadBody;
      return {
        event: payloadBody.topic,
        identifierValue: payloadBody.app_id,
      };
    },
    verify: ({ payload, webhookSecret }) => {
      const signature = payload.headers['x-hub-signature'];
      let hmac: crypto.Hmac;
      if (typeof webhookSecret === 'string') {
        hmac = crypto.createHmac('sha1', webhookSecret);
      } else {
        const app_id = (payload.body as PayloadBody).app_id;
        const webhookSecrets = webhookSecret as Record<string, string>;
        if (!(app_id in webhookSecrets)) {
          return false;
        }
        hmac = crypto.createHmac('sha1', webhookSecrets[app_id]);
      }
      hmac.update(`${payload.rawBody}`);
      const computedSignature = `sha1=${hmac.digest('hex')}`;
      return signature === computedSignature;
    },
	},
});

type PayloadBody = {
	type: string;
	topic: string;
	id: string;
	app_id: string;
};
